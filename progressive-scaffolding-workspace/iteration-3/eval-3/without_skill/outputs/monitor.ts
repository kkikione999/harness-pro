/**
 * Observability Monitor for Open-ClaudeCode
 *
 * A unified orchestrator that wires together logging, metrics, health checks,
 * and tracing into a single lifecycle manager. Provides the main entry point
 * for an AI agent to observe and understand the Open-ClaudeCode CLI's behavior.
 *
 * Integrates with the project's existing infrastructure:
 *   - OpenTelemetry pipeline (src/utils/telemetry/instrumentation.ts)
 *   - Analytics sink (src/services/analytics/sink.ts)
 *   - Session tracing (src/utils/telemetry/sessionTracing.ts)
 *   - BigQuery metrics exporter (src/utils/telemetry/bigqueryExporter.ts)
 *
 * Usage:
 *   const monitor = new ObservabilityMonitor({
 *     component: 'agent-observer',
 *     enablePrometheus: true,
 *     prometheusPort: 9464,
 *     healthPort: 8080,
 *   })
 *
 *   // Automatic system metrics collection starts immediately
 *   monitor.logger.info('monitor_started')
 *
 *   // Record a complete LLM interaction cycle
 *   monitor.traceLLMCycle({
 *     model: 'claude-sonnet-4-20250514',
 *     ttftMs: 340, ttltMs: 2500,
 *     inputTokens: 1200, outputTokens: 450,
 *     success: true,
 *   })
 *
 *   // Shutdown gracefully
 *   await monitor.shutdown()
 */

import { ObservabilityLogger } from './observability-logger.js'
import {
  MetricsCollector,
  type LLMRequestMetrics,
  type ToolInvocationMetrics,
  type InteractionMetrics,
} from './metrics-collector.js'
import { HealthChecker } from './health-check.js'
import {
  ObservabilityTracer,
  type Span,
  type SpanKind,
} from './tracing.js'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type MonitorConfig = {
  component: string
  sessionId?: string
  correlationId?: string
  logDir?: string
  logLevel?: 'debug' | 'info' | 'warn' | 'error'
  enableFileLogging?: boolean
  enableConsoleLogging?: boolean
  enableOTLPLogging?: boolean
  enablePrometheus?: boolean
  prometheusPort?: number
  enableHealthServer?: boolean
  healthPort?: number
  otlpEndpoint?: string
  traceSampleRate?: number
}

export type LLMCycleMetrics = LLMRequestMetrics & {
  interactionDurationMs?: number
  toolCalls?: number
  querySource?: string
}

export type ToolCycleMetrics = ToolInvocationMetrics & {
  permissionDecision?: string
  permissionSource?: string
  blockedOnUserMs?: number
}

// ---------------------------------------------------------------------------
// ObservabilityMonitor
// ---------------------------------------------------------------------------

export class ObservabilityMonitor {
  readonly logger: ObservabilityLogger
  readonly metrics: MetricsCollector
  readonly health: HealthChecker
  readonly tracer: ObservabilityTracer
  private readonly config: MonitorConfig
  private systemMetricsInterval: ReturnType<typeof setInterval> | null = null
  private readonly SYSTEM_METRICS_INTERVAL_MS = 30_000
  private shutdownRegistered = false

  constructor(config: MonitorConfig) {
    this.config = config

    // Initialize subsystems
    this.logger = new ObservabilityLogger({
      component: config.component,
      level: config.logLevel ?? 'info',
      logDir: config.logDir,
      enableFile: config.enableFileLogging ?? true,
      enableConsole: config.enableConsoleLogging ?? true,
      enableOTLP: config.enableOTLPLogging ?? false,
      correlationId: config.correlationId,
      sessionId: config.sessionId,
    })

    this.metrics = new MetricsCollector({
      otlpEndpoint: config.otlpEndpoint,
    })

    this.health = new HealthChecker()

    this.tracer = new ObservabilityTracer({
      serviceName: config.component,
      otlpEndpoint: config.otlpEndpoint,
      sampleRate: config.traceSampleRate ?? 1.0,
    })

    // Start subsystems
    if (config.enablePrometheus) {
      this.metrics.startPrometheusEndpoint(config.prometheusPort ?? 9464)
    }

    if (config.enableHealthServer) {
      this.health.startServer(config.healthPort ?? 8080)
    }

    this.startSystemMetricsCollection()
    this.registerShutdownHandlers()

    this.logger.info('monitor_initialized', {
      component: config.component,
      prometheus: String(!!config.enablePrometheus),
      health_server: String(!!config.enableHealthServer),
    })
  }

  // -- High-level composite recorders --------------------------------------

  /** Record a complete LLM request cycle with correlated logs, metrics, and traces. */
  traceLLMCycle(llm: LLMCycleMetrics): void {
    // Metrics
    this.metrics.recordLLMRequest(llm)

    // Tracing
    const span = this.tracer.traceLLMRequest({
      model: llm.model,
      querySource: llm.querySource,
      inputTokens: llm.inputTokens,
    })

    if (llm.ttftMs !== undefined) {
      span.addEvent('first_token', { ttft_ms: llm.ttftMs })
    }
    if (llm.ttltMs !== undefined) {
      span.addEvent('last_token', { ttlt_ms: llm.ttltMs })
    }

    span.end({
      status: llm.success ? 'ok' : 'error',
      statusMessage: llm.error,
      attributes: {
        success: llm.success,
        ...(llm.ttftMs !== undefined && { ttft_ms: llm.ttftMs }),
        ...(llm.ttltMs !== undefined && { ttlt_ms: llm.ttltMs }),
        ...(llm.inputTokens !== undefined && { input_tokens: llm.inputTokens }),
        ...(llm.outputTokens !== undefined && { output_tokens: llm.outputTokens }),
        ...(llm.cacheReadTokens !== undefined && { cache_read_tokens: llm.cacheReadTokens }),
        ...(llm.cacheCreationTokens !== undefined && {
          cache_creation_tokens: llm.cacheCreationTokens,
        }),
        ...(llm.attempt !== undefined && { attempt: llm.attempt }),
        ...(llm.error !== undefined && { error: llm.error }),
      },
    })

    // Logging
    if (llm.success) {
      this.logger.info('llm_request_completed', {
        model: llm.model,
        success: String(llm.success),
        ...(llm.ttftMs !== undefined && { ttft_ms: llm.ttftMs }),
        ...(llm.ttltMs !== undefined && { ttlt_ms: llm.ttltMs }),
        ...(llm.inputTokens !== undefined && { input_tokens: llm.inputTokens }),
        ...(llm.outputTokens !== undefined && { output_tokens: llm.outputTokens }),
      })
    } else {
      this.logger.error('llm_request_failed', {
        model: llm.model,
        error: llm.error ?? 'unknown',
        attempt: String(llm.attempt ?? 1),
      })
    }
  }

  /** Record a tool invocation cycle. */
  traceToolCycle(tool: ToolCycleMetrics): void {
    // Metrics
    this.metrics.recordToolInvocation(tool)

    // Tracing
    const span = this.tracer.traceToolInvocation({ tool: tool.tool })
    if (tool.blockedOnUserMs !== undefined) {
      span.addEvent('blocked_on_user', {
        duration_ms: tool.blockedOnUserMs,
        decision: tool.permissionDecision ?? 'unknown',
        source: tool.permissionSource ?? 'unknown',
      })
    }
    span.end({
      status: tool.success ? 'ok' : 'error',
      statusMessage: tool.error,
      attributes: {
        success: tool.success,
        duration_ms: tool.durationMs,
        ...(tool.resultTokens !== undefined && { result_tokens: tool.resultTokens }),
        ...(tool.error !== undefined && { error: tool.error }),
        ...(tool.permissionDecision && { permission_decision: tool.permissionDecision }),
      },
    })

    // Logging
    this.logger.info(tool.success ? 'tool_success' : 'tool_error', {
      tool: tool.tool.startsWith('mcp__') ? 'mcp_tool' : tool.tool,
      duration_ms: String(tool.durationMs),
      success: String(tool.success),
      ...(tool.error && { error: tool.error }),
      ...(tool.permissionDecision && { decision: tool.permissionDecision }),
    })
  }

  /** Record a full user interaction (prompt -> response cycle). */
  traceInteraction(interaction: InteractionMetrics): void {
    this.metrics.recordInteraction(interaction)

    this.logger.info('interaction_completed', {
      duration_ms: String(interaction.durationMs),
      tool_calls: String(interaction.toolCallCount),
      llm_requests: String(interaction.llmRequestCount),
      input_tokens: String(interaction.totalInputTokens),
      output_tokens: String(interaction.totalOutputTokens),
      prompt_length: String(interaction.userPromptLength),
    })
  }

  /** Record an error with full observability context. */
  traceError(error: Error, context?: Record<string, string | number | boolean>): void {
    const activeSpan = this.tracer.getActiveSpan()
    if (activeSpan) {
      activeSpan.recordException(error)
    }

    this.metrics.recordToolInvocation({
      tool: 'error',
      durationMs: 0,
      success: false,
      error: error.message,
    })

    this.logger.error('unhandled_error', {
      error_type: error.name,
      error_message: error.message,
      ...context,
    })
  }

  // -- Snapshot / diagnostics ----------------------------------------------

  /** Get a full diagnostic snapshot combining all subsystems. */
  async getDiagnosticSnapshot(): Promise<{
    health: ReturnType<HealthChecker['deepCheck']>
    metrics: ReturnType<MetricsCollector['getSnapshot']>
    active_spans: number
    completed_spans: number
    timestamp: string
  }> {
    const [healthResult] = await Promise.all([this.health.deepCheck()])

    return {
      health: healthResult,
      metrics: this.metrics.getSnapshot(),
      active_spans: this.tracer.getAllSpans().filter(s => !s.isEnded).length,
      completed_spans: this.tracer.getCompletedSpans().length,
      timestamp: new Date().toISOString(),
    }
  }

  // -- Lifecycle -----------------------------------------------------------

  /** Shut down all subsystems gracefully. */
  async shutdown(): Promise<void> {
    this.logger.info('monitor_shutting_down')

    if (this.systemMetricsInterval) {
      clearInterval(this.systemMetricsInterval)
      this.systemMetricsInterval = null
    }

    await Promise.all([
      this.tracer.shutdown(),
      this.metrics.shutdown(),
      this.health.shutdown(),
      this.logger.shutdown(),
    ])
  }

  // -- Internal ------------------------------------------------------------

  private startSystemMetricsCollection(): void {
    // Collect system metrics on a regular cadence
    this.systemMetricsInterval = setInterval(() => {
      const sysMetrics = this.metrics.recordSystemMetrics()

      // Log if memory is elevated
      const rssMb = sysMetrics.rss / (1024 * 1024)
      if (rssMb > 512) {
        this.logger.warn('memory_elevated', {
          rss_mb: String(Math.round(rssMb)),
          heap_used_mb: String(Math.round(sysMetrics.heapUsed / (1024 * 1024))),
          uptime_seconds: String(Math.round(sysMetrics.uptime)),
        })
      }

      // Log if event loop is lagging
      if (sysMetrics.eventLoopLagMs > 100) {
        this.logger.warn('event_loop_lag', {
          lag_ms: String(Math.round(sysMetrics.eventLoopLagMs)),
        })
      }
    }, this.SYSTEM_METRICS_INTERVAL_MS)

    if (this.systemMetricsInterval.unref) {
      this.systemMetricsInterval.unref()
    }
  }

  private registerShutdownHandlers(): void {
    if (this.shutdownRegistered) return
    this.shutdownRegistered = true

    const shutdown = async () => {
      try {
        await this.shutdown()
      } catch {
        // Best effort
      }
    }

    process.on('beforeExit', () => void shutdown())
    process.on('SIGTERM', () => void shutdown())
    process.on('SIGINT', () => void shutdown())
  }
}
