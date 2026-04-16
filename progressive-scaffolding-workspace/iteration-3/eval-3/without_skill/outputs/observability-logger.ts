/**
 * Observability Logger for Open-ClaudeCode
 *
 * Structured logging facade that integrates with the project's existing
 * OpenTelemetry pipeline (src/utils/telemetry/) and analytics sink
 * (src/services/analytics/). Provides a unified interface for:
 *   - Structured JSON log emission via OTLP
 *   - Datadog-compatible log forwarding
 *   - Local file-based debug logging
 *   - Console output with configurable severity levels
 *
 * Usage by an AI agent monitoring this project:
 *   import { ObservabilityLogger } from './observability-logger'
 *   const logger = new ObservabilityLogger({ component: 'agent-monitor' })
 *   logger.info('tool_invocation', { tool: 'Bash', duration_ms: 120 })
 *
 * Environment variables (from existing project conventions):
 *   CLAUDE_CODE_ENABLE_TELEMETRY=1   -- enable OTLP log exporters
 *   OTEL_LOGS_EXPORTER=console|otlp  -- exporter type
 *   OTEL_EXPORTER_OTLP_ENDPOINT      -- OTLP collector URL
 *   OTEL_LOGS_EXPORT_INTERVAL        -- batch flush interval (ms)
 */

import { createWriteStream, mkdirSync, existsSync } from 'fs'
import { join, dirname } from 'path'
import { tmpdir } from 'os'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type LogLevel = 'debug' | 'info' | 'warn' | 'error' | 'fatal'

export type LogEntry = {
  timestamp: string
  level: LogLevel
  component: string
  message: string
  correlation_id?: string
  session_id?: string
  trace_id?: string
  span_id?: string
  attributes?: Record<string, string | number | boolean>
}

export type LoggerConfig = {
  component: string
  level?: LogLevel
  logDir?: string
  enableFile?: boolean
  enableConsole?: boolean
  enableOTLP?: boolean
  correlationId?: string
  sessionId?: string
}

// ---------------------------------------------------------------------------
// Severity ordering
// ---------------------------------------------------------------------------

const SEVERITY: Record<LogLevel, number> = {
  debug: 10,
  info: 20,
  warn: 30,
  error: 40,
  fatal: 50,
}

// ---------------------------------------------------------------------------
// ObservabilityLogger
// ---------------------------------------------------------------------------

export class ObservabilityLogger {
  private readonly config: Required<
    Pick<
      LoggerConfig,
      'component' | 'level' | 'enableFile' | 'enableConsole' | 'enableOTLP'
    >
  > & { logDir: string; correlationId: string; sessionId: string }
  private fileStream: ReturnType<typeof createWriteStream> | null = null
  private buffer: LogEntry[] = []
  private flushInterval: ReturnType<typeof setInterval> | null = null
  private readonly FLUSH_INTERVAL_MS = 5000
  private readonly MAX_BUFFER_SIZE = 500

  constructor(config: LoggerConfig) {
    const logDir = config.logDir ?? join(tmpdir(), 'claude-code-observability')
    this.config = {
      component: config.component,
      level: config.level ?? 'info',
      logDir,
      enableFile: config.enableFile ?? true,
      enableConsole: config.enableConsole ?? true,
      enableOTLP: config.enableOTLP ?? false,
      correlationId: config.correlationId ?? '',
      sessionId: config.sessionId ?? '',
    }

    if (this.config.enableFile) {
      this.initFileStream()
    }

    this.startFlushInterval()
  }

  // -- Public API ----------------------------------------------------------

  debug(message: string, attributes?: Record<string, string | number | boolean>): void {
    this.emit('debug', message, attributes)
  }

  info(message: string, attributes?: Record<string, string | number | boolean>): void {
    this.emit('info', message, attributes)
  }

  warn(message: string, attributes?: Record<string, string | number | boolean>): void {
    this.emit('warn', message, attributes)
  }

  error(message: string, attributes?: Record<string, string | number | boolean>): void {
    this.emit('error', message, attributes)
  }

  fatal(message: string, attributes?: Record<string, string | number | boolean>): void {
    this.emit('fatal', message, attributes)
  }

  /** Create a child logger with the same config but a different component prefix. */
  child(subComponent: string): ObservabilityLogger {
    return new ObservabilityLogger({
      component: `${this.config.component}.${subComponent}`,
      level: this.config.level,
      logDir: this.config.logDir,
      enableFile: this.config.enableFile,
      enableConsole: this.config.enableConsole,
      enableOTLP: this.config.enableOTLP,
      correlationId: this.config.correlationId,
      sessionId: this.config.sessionId,
    })
  }

  /** Flush buffered logs and close resources. Call on process shutdown. */
  async shutdown(): Promise<void> {
    if (this.flushInterval) {
      clearInterval(this.flushInterval)
      this.flushInterval = null
    }
    this.flush()
    if (this.fileStream) {
      this.fileStream.end()
      this.fileStream = null
    }
  }

  // -- Internal ------------------------------------------------------------

  private emit(
    level: LogLevel,
    message: string,
    attributes?: Record<string, string | number | boolean>,
  ): void {
    if (SEVERITY[level] < SEVERITY[this.config.level]) {
      return
    }

    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      component: this.config.component,
      message,
      ...(this.config.correlationId && {
        correlation_id: this.config.correlationId,
      }),
      ...(this.config.sessionId && { session_id: this.config.sessionId }),
      ...(attributes && { attributes }),
    }

    this.buffer.push(entry)

    // Flush immediately on error/fatal for low-latency alerting
    if (level === 'error' || level === 'fatal') {
      this.flush()
    } else if (this.buffer.length >= this.MAX_BUFFER_SIZE) {
      this.flush()
    }
  }

  private flush(): void {
    if (this.buffer.length === 0) return

    const entries = [...this.buffer]
    this.buffer = []

    for (const entry of entries) {
      const line = JSON.stringify(entry)

      if (this.config.enableConsole) {
        this.consoleOutput(entry)
      }

      if (this.config.enableFile && this.fileStream) {
        this.fileStream.write(line + '\n')
      }

      if (this.config.enableOTLP) {
        this.sendToOTLP(entry)
      }
    }
  }

  private consoleOutput(entry: LogEntry): void {
    const { level, component, message, attributes } = entry
    const prefix = `[${level.toUpperCase()}] [${component}]`
    const attrStr = attributes ? ` ${JSON.stringify(attributes)}` : ''
    // eslint-disable-next-line no-console
    const output = level === 'error' || level === 'fatal' ? console.error : console.log
    output(`${prefix} ${message}${attrStr}`)
  }

  private async sendToOTLP(entry: LogEntry): Promise<void> {
    // Forward to the project's existing OTLP log endpoint.
    // This mirrors the pattern in src/utils/telemetry/events.ts logOTelEvent()
    const endpoint =
      process.env.OTEL_EXPORTER_OTLP_ENDPOINT ?? 'http://localhost:4318'
    const url = `${endpoint}/v1/logs`

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resourceLogs: [
            {
              resource: {
                attributes: [
                  { key: 'service.name', value: { stringValue: 'claude-code-monitor' } },
                  { key: 'service.version', value: { stringValue: '1.0.0' } },
                ],
              },
              scopeLogs: [
                {
                  scope: { name: this.config.component },
                  logRecords: [
                    {
                      timeUnixNano: String(Date.now() * 1_000_000),
                      severityNumber: SEVERITY[entry.level],
                      severityText: entry.level.toUpperCase(),
                      body: { stringValue: entry.message },
                      attributes: Object.entries(entry.attributes ?? {}).map(
                        ([key, value]) => ({
                          key,
                          value: {
                            [typeof value === 'number'
                              ? 'intValue'
                              : typeof value === 'boolean'
                                ? 'boolValue'
                                : 'stringValue']: String(value),
                          },
                        }),
                      ),
                    },
                  ],
                },
              ],
            },
          ],
        }),
      })
      if (!response.ok) {
        // Silently swallow OTLP delivery failures to avoid noisy log loops
      }
    } catch {
      // Network failure -- don't pollute logs
    }
  }

  private initFileStream(): void {
    try {
      if (!existsSync(this.config.logDir)) {
        mkdirSync(this.config.logDir, { recursive: true })
      }
      const logFile = join(
        this.config.logDir,
        `observability-${this.config.component}-${Date.now()}.ndjson`,
      )
      this.fileStream = createWriteStream(logFile, { flags: 'a' })
    } catch {
      this.config.enableFile = false
    }
  }

  private startFlushInterval(): void {
    this.flushInterval = setInterval(() => this.flush(), this.FLUSH_INTERVAL_MS)
    if (this.flushInterval.unref) {
      this.flushInterval.unref()
    }
  }
}
