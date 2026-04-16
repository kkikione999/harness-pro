/**
 * Telemetry Pipeline Monitor for Open-ClaudeCode Observability
 *
 * Monitors the health and throughput of the project's telemetry subsystems:
 *   - OpenTelemetry (metrics, logs, traces) from instrumentation.ts
 *   - BigQuery metrics export from bigqueryExporter.ts
 *   - Datadog event tracking from datadog.ts
 *   - 1P event logging from firstPartyEventLogger.ts
 *   - Perfetto tracing from perfettoTracing.ts
 *
 * Detects: export failures, flush timeouts, queue overflow, batch saturation,
 * and pipeline stalls. Designed for an AI agent to self-diagnose telemetry issues.
 *
 * Usage:
 *   const monitor = createTelemetryMonitor()
 *   monitor.onExport('bigquery', { success: true, metricsCount: 12 })
 *   monitor.onExport('datadog', { success: false, error: 'ECONNREFUSED' })
 *   const report = monitor.diagnose()
 */

// ---------- Types ----------

export type PipelineName = 'otlp_metrics' | 'otlp_logs' | 'otlp_traces' | 'bigquery' | 'datadog' | 'first_party' | 'perfetto'

export interface ExportEvent {
  pipeline: PipelineName
  success: boolean
  timestamp: string
  durationMs?: number
  itemCount?: number
  error?: string
  metadata?: Record<string, unknown>
}

export interface PipelineDiagnostics {
  pipeline: PipelineName
  enabled: boolean
  totalExports: number
  successfulExports: number
  failedExports: number
  lastExportAt: string | null
  lastError: string | null
  lastErrorAt: string | null
  consecutiveFailures: number
  totalItemsExported: number
  avgExportDurationMs: number
  /** Time since last successful export, null if never succeeded */
  timeSinceLastSuccessMs: number | null
  /** Whether this pipeline appears stalled */
  stalled: boolean
  /** Whether this pipeline has a degraded success rate */
  degraded: boolean
  status: 'healthy' | 'degraded' | 'stalled' | 'disabled' | 'error'
}

export interface TelemetryDiagnosticsReport {
  timestamp: string
  overallStatus: 'healthy' | 'degraded' | 'error'
  pipelines: PipelineDiagnostics[]
  recommendations: string[]
  envConfig: {
    CLAUDE_CODE_ENABLE_TELEMETRY: string | undefined
    OTEL_EXPORTER_OTLP_ENDPOINT: string | undefined
    OTEL_METRICS_EXPORTER: string | undefined
    OTEL_LOGS_EXPORTER: string | undefined
    OTEL_TRACES_EXPORTER: string | undefined
    OTEL_EXPORTER_OTLP_PROTOCOL: string | undefined
    CLAUDE_CODE_PERFETTO_TRACE: string | undefined
    ENABLE_ENHANCED_TELEMETRY_BETA: string | undefined
    OTEL_METRIC_EXPORT_INTERVAL: string | undefined
    OTEL_LOGS_EXPORT_INTERVAL: string | undefined
    OTEL_TRACES_EXPORT_INTERVAL: string | undefined
    CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS: string | undefined
  }
}

// ---------- Pipeline Monitor ----------

const MAX_EXPORT_HISTORY = 1000
const STALL_THRESHOLD_MS = 5 * 60 * 1000 // 5 minutes without export
const DEGRADED_SUCCESS_RATE = 0.8 // Less than 80% success is degraded

export function createTelemetryMonitor() {
  const exportHistory: ExportEvent[] = []
  const consecutiveFailures = new Map<PipelineName, number>()

  function recordExport(event: Omit<ExportEvent, 'timestamp'>): void {
    const fullEvent: ExportEvent = {
      ...event,
      timestamp: new Date().toISOString(),
    }

    // Bounded history (evict oldest half, matching perfettoTracing.ts pattern)
    if (exportHistory.length >= MAX_EXPORT_HISTORY) {
      exportHistory.splice(0, MAX_EXPORT_HISTORY / 2)
    }
    exportHistory.push(fullEvent)

    // Track consecutive failures
    if (event.success) {
      consecutiveFailures.set(event.pipeline, 0)
    } else {
      consecutiveFailures.set(event.pipeline, (consecutiveFailures.get(event.pipeline) || 0) + 1)
    }
  }

  function getPipelineEvents(pipeline: PipelineName): ExportEvent[] {
    return exportHistory.filter(e => e.pipeline === pipeline)
  }

  function diagnosePipeline(pipeline: PipelineName): PipelineDiagnostics {
    const events = getPipelineEvents(pipeline)
    const successes = events.filter(e => e.success)
    const failures = events.filter(e => !e.success)
    const now = Date.now()

    // Determine if pipeline is enabled
    const enabled = isPipelineEnabled(pipeline)

    // Compute stats
    const totalExports = events.length
    const successfulExports = successes.length
    const failedExports = failures.length
    const lastExport = events.length > 0 ? events[events.length - 1] : null
    const lastSuccess = successes.length > 0 ? successes[successes.length - 1] : null
    const lastFailure = failures.length > 0 ? failures[failures.length - 1] : null

    const totalItems = events.reduce((sum, e) => sum + (e.itemCount || 0), 0)
    const durationsWithValues = events.filter(e => e.durationMs !== undefined)
    const avgDurationMs = durationsWithValues.length > 0
      ? durationsWithValues.reduce((sum, e) => sum + (e.durationMs || 0), 0) / durationsWithValues.length
      : 0

    const timeSinceLastSuccessMs = lastSuccess
      ? now - new Date(lastSuccess.timestamp).getTime()
      : null

    const consecFails = consecutiveFailures.get(pipeline) || 0

    // Determine status
    let status: PipelineDiagnostics['status'] = 'healthy'
    let stalled = false
    let degraded = false

    if (!enabled) {
      status = 'disabled'
    } else if (consecFails >= 5) {
      status = 'error'
    } else if (timeSinceLastSuccessMs !== null && timeSinceLastSuccessMs > STALL_THRESHOLD_MS) {
      stalled = true
      status = 'stalled'
    } else if (totalExports > 10 && successfulExports / totalExports < DEGRADED_SUCCESS_RATE) {
      degraded = true
      status = 'degraded'
    } else if (lastFailure && !lastSuccess) {
      // Only failures, never succeeded
      status = 'error'
    }

    return {
      pipeline,
      enabled,
      totalExports,
      successfulExports,
      failedExports,
      lastExportAt: lastExport?.timestamp ?? null,
      lastError: lastFailure?.error ?? null,
      lastErrorAt: lastFailure?.timestamp ?? null,
      consecutiveFailures: consecFails,
      totalItemsExported: totalItems,
      avgExportDurationMs: Math.round(avgDurationMs),
      timeSinceLastSuccessMs,
      stalled,
      degraded,
      status,
    }
  }

  function diagnose(): TelemetryDiagnosticsReport {
    const pipelines: PipelineName[] = [
      'otlp_metrics', 'otlp_logs', 'otlp_traces',
      'bigquery', 'datadog', 'first_party', 'perfetto',
    ]

    const pipelineResults = pipelines.map(diagnosePipeline)
    const recommendations = generateRecommendations(pipelineResults)

    // Overall status: worst pipeline status wins
    let overallStatus: TelemetryDiagnosticsReport['overallStatus'] = 'healthy'
    for (const p of pipelineResults) {
      if (p.status === 'error') { overallStatus = 'error'; break }
      if (p.status === 'stalled' || p.status === 'degraded') { overallStatus = 'degraded' }
    }

    return {
      timestamp: new Date().toISOString(),
      overallStatus,
      pipelines: pipelineResults,
      recommendations,
      envConfig: captureEnvConfig(),
    }
  }

  function generateRecommendations(pipelineResults: PipelineDiagnostics[]): string[] {
    const recs: string[] = []

    for (const p of pipelineResults) {
      if (p.status === 'disabled' && p.pipeline.startsWith('otlp_')) {
        recs.push(`${p.pipeline}: Telemetry not enabled. Set CLAUDE_CODE_ENABLE_TELEMETRY=1 to enable.`)
      }
      if (p.status === 'error' && p.consecutiveFailures >= 5) {
        recs.push(`${p.pipeline}: ${p.consecutiveFailures} consecutive failures. Last error: ${p.lastError}. Check endpoint connectivity and credentials.`)
      }
      if (p.stalled) {
        recs.push(`${p.pipeline}: No successful export in ${Math.round((p.timeSinceLastSuccessMs || 0) / 1000)}s. Pipeline may be stalled.`)
      }
      if (p.degraded) {
        const successRate = p.totalExports > 0 ? (p.successfulExports / p.totalExports * 100).toFixed(0) : '0'
        recs.push(`${p.pipeline}: Success rate ${successRate}% (below 80%). Investigate intermittent failures.`)
      }
    }

    // Check for specific known issues
    const otlpEndpoint = process.env.OTEL_EXPORTER_OTLP_ENDPOINT
    if (otlpEndpoint && otlpEndpoint.includes('localhost') && process.env.CI) {
      recs.push('OTEL_EXPORTER_OTLP_ENDPOINT points to localhost in CI. Use a proper collector endpoint.')
    }

    const shutdownTimeout = parseInt(process.env.CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS || '2000')
    if (shutdownTimeout < 2000) {
      recs.push(`Shutdown timeout is ${shutdownTimeout}ms (< 2000ms). Telemetry may be lost on exit. Increase CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS.`)
    }

    return recs
  }

  function reset(): void {
    exportHistory.length = 0
    consecutiveFailures.clear()
  }

  return {
    recordExport,
    diagnose,
    reset,
  }
}

// ---------- Helpers ----------

function isPipelineEnabled(pipeline: PipelineName): boolean {
  switch (pipeline) {
    case 'otlp_metrics':
    case 'otlp_logs':
    case 'otlp_traces':
      return !!process.env.CLAUDE_CODE_ENABLE_TELEMETRY
    case 'bigquery':
      // Enabled for 1P API customers and C4E/team users (mirrors instrumentation.ts)
      return !!process.env.CLAUDE_CODE_ENABLE_TELEMETRY || !!process.env.ANTHROPIC_API_KEY
    case 'datadog':
      return true // Always enabled (gated by feature flag at runtime)
    case 'first_party':
      return true // Always enabled (gated by isAnalyticsDisabled at runtime)
    case 'perfetto':
      return !!process.env.CLAUDE_CODE_PERFETTO_TRACE
  }
}

function captureEnvConfig(): TelemetryDiagnosticsReport['envConfig'] {
  return {
    CLAUDE_CODE_ENABLE_TELEMETRY: process.env.CLAUDE_CODE_ENABLE_TELEMETRY,
    OTEL_EXPORTER_OTLP_ENDPOINT: process.env.OTEL_EXPORTER_OTLP_ENDPOINT,
    OTEL_METRICS_EXPORTER: process.env.OTEL_METRICS_EXPORTER,
    OTEL_LOGS_EXPORTER: process.env.OTEL_LOGS_EXPORTER,
    OTEL_TRACES_EXPORTER: process.env.OTEL_TRACES_EXPORTER,
    OTEL_EXPORTER_OTLP_PROTOCOL: process.env.OTEL_EXPORTER_OTLP_PROTOCOL,
    CLAUDE_CODE_PERFETTO_TRACE: process.env.CLAUDE_CODE_PERFETTO_TRACE,
    ENABLE_ENHANCED_TELEMETRY_BETA: process.env.ENABLE_ENHANCED_TELEMETRY_BETA,
    OTEL_METRIC_EXPORT_INTERVAL: process.env.OTEL_METRIC_EXPORT_INTERVAL,
    OTEL_LOGS_EXPORT_INTERVAL: process.env.OTEL_LOGS_EXPORT_INTERVAL,
    OTEL_TRACES_EXPORT_INTERVAL: process.env.OTEL_TRACES_EXPORT_INTERVAL,
    CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS: process.env.CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS,
  }
}
