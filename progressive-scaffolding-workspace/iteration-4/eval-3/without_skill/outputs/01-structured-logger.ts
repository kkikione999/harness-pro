/**
 * Structured Logger for Open-ClaudeCode Observability
 *
 * Provides a leveled, structured logging framework that mirrors the project's
 * existing telemetry patterns (ClaudeCodeDiagLogger, logForDebugging) but adds
 * agent-friendly structured output with consistent schemas.
 *
 * Usage by AI agents:
 *   import { createLogger } from './01-structured-logger'
 *   const log = createLogger('session-tracing')
 *   log.info('span_started', { spanType: 'interaction', spanId: 'abc123' })
 *   log.error('span_failed', { spanType: 'tool', error: 'ECONNREFUSED' })
 */

// ---------- Types ----------

export type LogLevel = 'debug' | 'info' | 'warn' | 'error' | 'fatal'

export interface LogEntry {
  timestamp: string
  level: LogLevel
  component: string
  message: string
  traceId?: string
  spanId?: string
  sessionId?: string
  durationMs?: number
  metadata?: Record<string, unknown>
}

export interface LoggerConfig {
  component: string
  minLevel?: LogLevel
  // Custom sink — defaults to stderr for CLI context (avoids stdout JSON protocol)
  sink?: (entry: LogEntry) => void
  // Enrich every entry with fixed context
  defaultContext?: Record<string, unknown>
}

// ---------- Log level ordering ----------

const LEVEL_ORDER: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
  fatal: 4,
}

function shouldLog(entryLevel: LogLevel, minLevel: LogLevel): boolean {
  return LEVEL_ORDER[entryLevel] >= LEVEL_ORDER[minLevel]
}

// ---------- Default sink (stderr, JSON lines) ----------

function defaultSink(entry: LogEntry): void {
  const line = JSON.stringify(entry)
  process.stderr.write(line + '\n')
}

// ---------- Logger creation ----------

export function createLogger(config: LoggerConfig) {
  const minLevel = config.minLevel ?? 'info'
  const sink = config.sink ?? defaultSink
  const defaultCtx = config.defaultContext ?? {}

  function emit(level: LogLevel, message: string, metadata?: Record<string, unknown>): void {
    if (!shouldLog(level, minLevel)) return

    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level,
      component: config.component,
      message,
      ...defaultCtx,
      ...(metadata && Object.keys(metadata).length > 0 ? { metadata } : {}),
    }

    sink(entry)
  }

  return {
    debug: (msg: string, meta?: Record<string, unknown>) => emit('debug', msg, meta),
    info: (msg: string, meta?: Record<string, unknown>) => emit('info', msg, meta),
    warn: (msg: string, meta?: Record<string, unknown>) => emit('warn', msg, meta),
    error: (msg: string, meta?: Record<string, unknown>) => emit('error', msg, meta),
    fatal: (msg: string, meta?: Record<string, unknown>) => emit('fatal', msg, meta),

    /** Create a child logger that inherits context but adds extra defaults. */
    child(extraContext: Record<string, unknown>) {
      return createLogger({
        ...config,
        defaultContext: { ...defaultCtx, ...extraContext },
      })
    },

    /** Time a synchronous or asynchronous operation. */
    async measure<T>(label: string, fn: () => Promise<T>): Promise<T> {
      const start = Date.now()
      try {
        const result = await fn()
        emit('info', `${label}_completed`, { durationMs: Date.now() - start })
        return result
      } catch (err) {
        emit('error', `${label}_failed`, {
          durationMs: Date.now() - start,
          error: err instanceof Error ? err.message : String(err),
        })
        throw err
      }
    },

    /** Emit a correlation-ready entry linking to a trace/span. */
    withTrace(traceId: string, spanId?: string) {
      return createLogger({
        ...config,
        defaultContext: { ...defaultCtx, traceId, ...(spanId ? { spanId } : {}) },
      })
    },
  }
}

// ---------- Convenience: session-aware logger factory ----------

/**
 * Pre-wired logger for the Open-ClaudeCode session lifecycle.
 * Reads CLAUDE_CODE_SESSION_ID and CLAUDE_CODE_AGENT_ID from env when present.
 */
export function createSessionLogger(component: string) {
  const sessionId = process.env.CLAUDE_CODE_SESSION_ID
  const agentId = process.env.CLAUDE_CODE_AGENT_ID
  return createLogger({
    component,
    defaultContext: {
      ...(sessionId ? { sessionId } : {}),
      ...(agentId ? { agentId } : {}),
    },
  })
}
