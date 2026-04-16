/**
 * Observability Integration - Unified facade for Open-ClaudeCode
 *
 * Wires together all observability primitives into a single entry point
 * that an AI agent can use to monitor the CLI's behavior end-to-end.
 *
 * Integrates:
 *   - Structured logging (01-structured-logger.ts)
 *   - Metrics collection (02-metrics-collector.ts)
 *   - Health checking (03-health-checker.ts)
 *   - Session tracing (04-session-tracer.ts)
 *   - Telemetry pipeline monitoring (05-telemetry-pipeline-monitor.ts)
 *   - Analytics event inspection (06-analytics-event-inspector.ts)
 *
 * Usage:
 *   const obs = createObservability({ sessionId: 'abc-123' })
 *   obs.init()  // Run health checks, attach monitors
 *
 *   // During session:
 *   obs.trace.apiCall('claude-sonnet-4', { inputTokens: 1500, ttftMs: 340, ... })
 *   obs.metrics.recordToolCall({ toolName: 'Read', durationMs: 45, success: true })
 *
 *   // Diagnose issues:
 *   const diag = obs.diagnose()
 *   if (diag.health.status !== 'pass') { ... }
 */

import { createSessionLogger } from './01-structured-logger'
import { createCliMetrics } from './02-metrics-collector'
import { runHealthCheck, formatHealthReport } from './03-health-checker'
import { createSessionTracer } from './04-session-tracer'
import { createTelemetryMonitor } from './05-telemetry-pipeline-monitor'
import { createEventInspector } from './06-analytics-event-inspector'

// ---------- Types ----------

export interface ObservabilityConfig {
  sessionId: string
  agentId?: string
  /** Minimum log level (default: 'info') */
  minLogLevel?: 'debug' | 'info' | 'warn' | 'error'
  /** Whether to run health checks on init (default: true) */
  runHealthChecks?: boolean
  /** Custom health check options */
  healthCheckOptions?: Parameters<typeof runHealthCheck>[0]
}

export interface DiagnosticReport {
  timestamp: string
  sessionId: string
  health: Awaited<ReturnType<typeof runHealthCheck>>
  telemetry: ReturnType<ReturnType<typeof createTelemetryMonitor>['diagnose']>
  traceSummary: ReturnType<ReturnType<typeof createSessionTracer>['summary']>
  metricsSnapshot: ReturnType<ReturnType<typeof createCliMetrics>['snapshot']>
  events: ReturnType<ReturnType<typeof createEventInspector>['report']>
  recommendations: string[]
}

// ---------- Observability facade ----------

export function createObservability(config: ObservabilityConfig) {
  const sessionId = config.sessionId

  // Initialize subsystems
  const logger = createSessionLogger('observability')
  const metrics = createCliMetrics()
  const tracer = createSessionTracer(sessionId)
  const telemetryMonitor = createTelemetryMonitor()
  const eventInspector = createEventInspector()

  let initialized = false
  let lastHealthCheck: Awaited<ReturnType<typeof runHealthCheck>> | null = null

  // ---------- Init ----------

  async function init(): Promise<void> {
    if (initialized) return
    initialized = true

    logger.info('observability_initializing', { sessionId })

    if (config.runHealthChecks !== false) {
      try {
        lastHealthCheck = await runHealthCheck(config.healthCheckOptions)
        if (lastHealthCheck.status !== 'pass') {
          logger.warn('health_check_issues', {
            status: lastHealthCheck.status,
            failedChecks: lastHealthCheck.checks
              .filter(c => c.status !== 'pass')
              .map(c => c.name),
          })
        }
      } catch (err) {
        logger.error('health_check_failed', {
          error: err instanceof Error ? err.message : String(err),
        })
      }
    }

    logger.info('observability_initialized', { sessionId })
  }

  // ---------- Convenience wrappers for common operations ----------

  const trace = {
    /** Start and end an interaction span around a function. */
    async interaction<T>(userPrompt: string, fn: () => Promise<T>): Promise<T> {
      const spanId = tracer.startInteraction(userPrompt)
      try {
        const result = await fn()
        tracer.endInteraction(spanId)
        metrics.recordSpan({ spanType: 'interaction', durationMs: 0, ended: true })
        return result
      } catch (err) {
        tracer.endInteraction(spanId)
        metrics.recordSpan({ spanType: 'interaction', durationMs: 0, ended: true })
        throw err
      }
    },

    /** Record a completed API call with full metrics. */
    apiCall(params: {
      model: string
      durationMs: number
      inputTokens?: number
      outputTokens?: number
      cacheReadTokens?: number
      cacheCreationTokens?: number
      ttftMs?: number
      status: number
      success: boolean
      error?: string
    }) {
      const spanId = tracer.startLLMRequest(params.model)
      tracer.endLLMRequest(spanId, {
        inputTokens: params.inputTokens,
        outputTokens: params.outputTokens,
        cacheReadTokens: params.cacheReadTokens,
        cacheCreationTokens: params.cacheCreationTokens,
        ttftMs: params.ttftMs,
        success: params.success,
        statusCode: params.status,
        error: params.error,
      })

      metrics.recordApiCall({
        model: params.model,
        status: params.status,
        durationMs: params.durationMs,
        inputTokens: params.inputTokens,
        outputTokens: params.outputTokens,
        cacheReadTokens: params.cacheReadTokens,
        cacheCreationTokens: params.cacheCreationTokens,
        ttftMs: params.ttftMs,
        success: params.success,
      })

      logger.info('api_call_completed', {
        model: params.model,
        status: params.status,
        durationMs: params.durationMs,
        success: params.success,
      })

      // Record in telemetry monitor
      telemetryMonitor.recordExport({
        pipeline: 'otlp_metrics',
        success: params.success,
        itemCount: 1,
        error: params.error,
      })
    },

    /** Record a tool invocation with timing. */
    toolCall(params: {
      toolName: string
      durationMs: number
      success: boolean
      error?: string
      resultTokens?: number
    }) {
      const spanId = tracer.startTool(params.toolName)
      tracer.endTool(spanId, {
        toolName: params.toolName,
        success: params.success,
        error: params.error,
        resultTokens: params.resultTokens,
      })

      metrics.recordToolCall(params)

      logger.info('tool_call_completed', {
        tool: params.toolName.startsWith('mcp__') ? 'mcp' : params.toolName,
        durationMs: params.durationMs,
        success: params.success,
      })
    },

    /** Record a permission decision. */
    permissionDecision(params: {
      toolName: string
      decision: 'granted' | 'denied' | 'cancelled'
      source: string
      waitTimeMs: number
    }) {
      const spanId = tracer.startPermissionWait(params.toolName)
      tracer.endPermissionWait(spanId, {
        decision: params.decision,
        source: params.source,
      })

      metrics.recordPermissionDecision(params)

      logger.info('permission_decision', {
        tool: params.toolName,
        decision: params.decision,
        waitTimeMs: params.waitTimeMs,
      })
    },

    /** Record an analytics event. */
    analyticsEvent(
      eventName: string,
      metadata: Record<string, boolean | number | undefined>,
      source: 'datadog' | 'first_party' | 'otel' = 'datadog',
    ) {
      const result = eventInspector.capture(eventName, metadata, source)
      if (!result.valid) {
        logger.warn('analytics_event_violation', {
          eventName,
          violations: result.violations,
        })
      }
    },
  }

  // ---------- Diagnostics ----------

  async function diagnose(): Promise<DiagnosticReport> {
    logger.info('running_diagnostics')

    // Refresh health checks
    const health = await runHealthCheck(config.healthCheckOptions)
    lastHealthCheck = health

    const telemetry = telemetryMonitor.diagnose()
    const traceSummary = tracer.summary()
    const metricsSnapshot = metrics.snapshot()
    const events = eventInspector.report()

    // Aggregate recommendations from all subsystems
    const recommendations = [
      ...telemetry.recommendations,
      ...events.piiWarnings.map(w => `PII warning: ${w}`),
      ...events.missingEvents.map(e => `Expected session event not seen: ${e}`),
    ]

    // Add health-based recommendations
    for (const check of health.checks) {
      if (check.status === 'fail') {
        recommendations.push(`Health check failed: ${check.name} - ${check.message}`)
      }
    }

    // Add metrics-based recommendations
    const apiErrors = metricsSnapshot.counters.find(c => c.name === 'api.errors')
    if (apiErrors && apiErrors.value > 5) {
      recommendations.push(`High API error count: ${apiErrors.value}. Investigate API connectivity or rate limits.`)
    }

    return {
      timestamp: new Date().toISOString(),
      sessionId,
      health,
      telemetry,
      traceSummary,
      metricsSnapshot,
      events,
      recommendations,
    }
  }

  // ---------- Export ----------

  function exportAll(): {
    trace: ReturnType<typeof tracer.exportTrace>
    metrics: ReturnType<typeof metrics.snapshot>
    events: ReturnType<typeof eventInspector.report>
  } {
    return {
      trace: tracer.exportTrace(),
      metrics: metrics.snapshot(),
      events: eventInspector.report(),
    }
  }

  /** Format a human-readable diagnostic summary. */
  async function formatDiagnosticSummary(): Promise<string> {
    const report = await diagnose()
    const lines: string[] = [
      `=== Observability Diagnostic Report ===`,
      `Session: ${report.sessionId}`,
      `Time: ${report.timestamp}`,
      '',
      `--- Health: ${report.health.status.toUpperCase()} ---`,
      formatHealthReport(report.health),
      '',
      `--- Telemetry: ${report.telemetry.overallStatus.toUpperCase()} ---`,
      ...report.telemetry.pipelines
        .filter(p => p.enabled)
        .map(p => `  [${p.status.toUpperCase()}] ${p.pipeline}: ${p.successfulExports}/${p.totalExports} exports ok`),
      '',
      `--- Traces ---`,
      `  Active spans: ${report.traceSummary.activeSpanCount}`,
      `  Completed spans: ${report.traceSummary.completedSpanCount}`,
      `  Errors: ${report.traceSummary.errorCount}`,
      `  Types: ${Object.entries(report.traceSummary.spanTypes).map(([t, c]) => `${t}=${c}`).join(', ')}`,
      '',
      `--- Events ---`,
      `  Total: ${report.events.totalEvents}`,
      `  Valid: ${report.events.validEvents}`,
      `  Invalid: ${report.events.invalidEvents}`,
      `  Unknown: ${report.events.unknownEvents.length}`,
      `  PII warnings: ${report.events.piiWarnings.length}`,
      '',
      `--- Recommendations (${report.recommendations.length}) ---`,
      ...report.recommendations.map(r => `  - ${r}`),
    ]

    return lines.join('\n')
  }

  return {
    init,
    logger,
    metrics,
    trace,
    diagnose,
    exportAll,
    formatDiagnosticSummary,
    // Direct access to subsystems for advanced usage
    _tracer: tracer,
    _telemetryMonitor: telemetryMonitor,
    _eventInspector: eventInspector,
  }
}
