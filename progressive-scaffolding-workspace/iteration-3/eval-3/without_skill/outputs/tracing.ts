/**
 * Distributed Tracing for Open-ClaudeCode
 *
 * Provides tracing utilities that align with the project's existing session
 * tracing infrastructure (src/utils/telemetry/sessionTracing.ts) and Perfetto
 * tracing (src/utils/telemetry/perfettoTracing.ts).
 *
 * This module gives an AI agent monitoring the project the ability to:
 *   - Create and manage trace spans for any operation
 *   - Propagate trace context across async boundaries
 *   - Export traces in OTLP JSON format for Jaeger/Zipkin/Tempo
 *   - Generate Chrome Trace Event format for Perfetto UI visualization
 *   - Correlate spans across LLM requests, tool calls, and hooks
 *
 * Span hierarchy mirrors the project's tracing model:
 *   interaction -> llm_request -> [sampling, first_token]
 *   interaction -> tool -> tool.blocked_on_user
 *                     -> tool.execution
 *   interaction -> hook
 *
 * Usage:
 *   const tracer = new ObservabilityTracer({ serviceName: 'agent-monitor' })
 *   const span = tracer.startSpan('agent.task', { attributes: { task: 'refactor' } })
 *   // ... do work ...
 *   span.end({ attributes: { success: true, duration_ms: 500 } })
 *   tracer.flush() // send to OTLP endpoint
 */

import { randomUUID } from 'crypto'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type SpanStatus = 'ok' | 'error' | 'unset'

export type SpanKind = 'internal' | 'client' | 'server' | 'producer' | 'consumer'

export interface SpanContext {
  traceId: string
  spanId: string
  parentSpanId?: string
}

export interface SpanData {
  name: string
  context: SpanContext
  kind: SpanKind
  startTime: number // epoch microseconds
  endTime?: number
  status: SpanStatus
  statusMessage?: string
  attributes: Record<string, string | number | boolean>
  events: SpanEvent[]
  links: SpanLink[]
}

export interface SpanEvent {
  name: string
  timestamp: number
  attributes: Record<string, string | number | boolean>
}

export interface SpanLink {
  context: SpanContext
  attributes: Record<string, string | number | boolean>
}

export interface TracerConfig {
  serviceName: string
  serviceVersion?: string
  otlpEndpoint?: string
  sampleRate?: number // 0-1, default 1.0 (always sample)
  maxSpans?: number // max spans in memory before eviction, default 10000
}

// ---------------------------------------------------------------------------
// Span
// ---------------------------------------------------------------------------

export class Span {
  readonly data: SpanData

  constructor(data: SpanData) {
    this.data = data
  }

  setAttribute(key: string, value: string | number | boolean): this {
    this.data.attributes[key] = value
    return this
  }

  setAttributes(attrs: Record<string, string | number | boolean>): this {
    for (const [key, value] of Object.entries(attrs)) {
      this.data.attributes[key] = value
    }
    return this
  }

  addEvent(name: string, attributes: Record<string, string | number | boolean> = {}): this {
    this.data.events.push({
      name,
      timestamp: Date.now() * 1000,
      attributes,
    })
    return this
  }

  addLink(context: SpanContext, attributes: Record<string, string | number | boolean> = {}): this {
    this.data.links.push({ context, attributes })
    return this
  }

  setStatus(status: SpanStatus, message?: string): this {
    this.data.status = status
    if (message) this.data.statusMessage = message
    return this
  }

  recordException(error: Error): this {
    this.data.status = 'error'
    this.data.statusMessage = error.message
    this.addEvent('exception', {
      'exception.type': error.name,
      'exception.message': error.message,
      'exception.stacktrace': error.stack ?? '',
    })
    return this
  }

  end(options?: {
    attributes?: Record<string, string | number | boolean>
    status?: SpanStatus
    statusMessage?: string
  }): void {
    if (this.data.endTime) return // Already ended

    this.data.endTime = Date.now() * 1000

    if (options?.attributes) {
      this.setAttributes(options.attributes)
    }
    if (options?.status) {
      this.data.status = options.status
    }
    if (options?.statusMessage) {
      this.data.statusMessage = options.statusMessage
    }
  }

  get isEnded(): boolean {
    return this.data.endTime !== undefined
  }

  get durationUs(): number | undefined {
    if (!this.data.endTime) return undefined
    return this.data.endTime - this.data.startTime
  }

  get context(): SpanContext {
    return this.data.context
  }
}

// ---------------------------------------------------------------------------
// ObservabilityTracer
// ---------------------------------------------------------------------------

export class ObservabilityTracer {
  private readonly config: Required<
    Pick<TracerConfig, 'serviceName' | 'serviceVersion' | 'sampleRate' | 'maxSpans'>
  > & { otlpEndpoint: string | null }
  private readonly spans: Span[] = []
  private activeSpanStack: Span[] = []
  private flushInterval: ReturnType<typeof setInterval> | null = null
  private readonly FLUSH_INTERVAL_MS = 5000

  constructor(config: TracerConfig) {
    this.config = {
      serviceName: config.serviceName,
      serviceVersion: config.serviceVersion ?? '1.0.0',
      sampleRate: config.sampleRate ?? 1.0,
      maxSpans: config.maxSpans ?? 10000,
      otlpEndpoint: config.otlpEndpoint ?? process.env.OTEL_EXPORTER_OTLP_ENDPOINT ?? null,
    }

    this.startFlushInterval()
  }

  // -- Span creation -------------------------------------------------------

  startSpan(
    name: string,
    options?: {
      kind?: SpanKind
      parent?: Span | SpanContext
      attributes?: Record<string, string | number | boolean>
    },
  ): Span {
    // Sampling decision
    if (Math.random() > this.config.sampleRate) {
      // Return a no-op span that records nothing
      return new Span({
        name: `${name}.sampled`,
        context: { traceId: '0'.repeat(32), spanId: '0'.repeat(16) },
        kind: options?.kind ?? 'internal',
        startTime: 0,
        status: 'unset',
        attributes: { sampled: false },
        events: [],
        links: [],
      })
    }

    const parentContext = options?.parent
      ? options.parent instanceof Span
        ? options.parent.context
        : options.parent
      : this.getActiveSpan()?.context

    const spanContext: SpanContext = {
      traceId: parentContext?.traceId ?? randomUUID().replace(/-/g, ''),
      spanId: randomUUID().replace(/-/g, '').slice(0, 16),
      parentSpanId: parentContext?.spanId,
    }

    const span = new Span({
      name,
      context: spanContext,
      kind: options?.kind ?? 'internal',
      startTime: Date.now() * 1000,
      status: 'unset',
      attributes: {
        'service.name': this.config.serviceName,
        'service.version': this.config.serviceVersion,
        ...(options?.attributes ?? {}),
      },
      events: [],
      links: [],
    })

    this.spans.push(span)
    this.evictOldSpans()

    return span
  }

  /** Start a span and push it onto the active span stack. */
  startActiveSpan(
    name: string,
    options?: Parameters<typeof this.startSpan>[1],
  ): Span {
    const span = this.startSpan(name, {
      ...options,
      parent: options?.parent ?? this.getActiveSpan(),
    })
    this.activeSpanStack.push(span)
    return span
  }

  /** End the current active span and pop it from the stack. */
  endActiveSpan(
    options?: Parameters<Span['end']>[0],
  ): Span | undefined {
    const span = this.activeSpanStack.pop()
    if (span) {
      span.end(options)
    }
    return span
  }

  /** Get the current active span (top of stack). */
  getActiveSpan(): Span | undefined {
    return this.activeSpanStack[this.activeSpanStack.length - 1]
  }

  /** Execute a function within a span context. */
  async withSpan<T>(
    name: string,
    fn: (span: Span) => Promise<T>,
    options?: {
      kind?: SpanKind
      attributes?: Record<string, string | number | boolean>
    },
  ): Promise<T> {
    const span = this.startActiveSpan(name, options)
    try {
      const result = await fn(span)
      span.setStatus('ok')
      return result
    } catch (error) {
      if (error instanceof Error) {
        span.recordException(error)
      } else {
        span.setStatus('error', String(error))
      }
      throw error
    } finally {
      this.endActiveSpan()
    }
  }

  // -- Convenience methods for common CLI operation types ------------------

  /** Trace an LLM API request. */
  traceLLMRequest(options: {
    model: string
    querySource?: string
    inputTokens?: number
    parent?: Span
  }): Span {
    return this.startSpan('claude_code.llm_request', {
      kind: 'client',
      parent: options.parent,
      attributes: {
        'span.type': 'llm_request',
        model: options.model,
        'query_source': options.querySource ?? 'unknown',
        ...(options.inputTokens !== undefined && {
          'input_tokens': options.inputTokens,
        }),
      },
    })
  }

  /** Trace a tool invocation. */
  traceToolInvocation(options: {
    tool: string
    parent?: Span
  }): Span {
    return this.startSpan('claude_code.tool', {
      kind: 'internal',
      parent: options.parent,
      attributes: {
        'span.type': 'tool',
        tool_name: options.tool.startsWith('mcp__') ? 'mcp_tool' : options.tool,
      },
    })
  }

  /** Trace a full user interaction cycle. */
  traceInteraction(options: {
    userPromptLength: number
  }): Span {
    return this.startActiveSpan('claude_code.interaction', {
      kind: 'internal',
      attributes: {
        'span.type': 'interaction',
        'user_prompt_length': options.userPromptLength,
      },
    })
  }

  // -- Export --------------------------------------------------------------

  /** Get all completed spans. */
  getCompletedSpans(): Span[] {
    return this.spans.filter(s => s.isEnded)
  }

  /** Get all spans (including active). */
  getAllSpans(): Span[] {
    return [...this.spans]
  }

  /** Export spans in OTLP JSON format. */
  toOTLP(): Record<string, unknown> {
    const completed = this.getCompletedSpans()

    return {
      resourceSpans: [
        {
          resource: {
            attributes: [
              { key: 'service.name', value: { stringValue: this.config.serviceName } },
              { key: 'service.version', value: { stringValue: this.config.serviceVersion } },
            ],
          },
          scopeSpans: [
            {
              scope: { name: this.config.serviceName },
              spans: completed.map(span => ({
                traceId: span.data.context.traceId,
                spanId: span.data.context.spanId,
                parentSpanId: span.data.context.parentSpanId,
                name: span.data.name,
                kind: this.spanKindToOTLP(span.data.kind),
                startTimeUnixNano: String(span.data.startTime * 1000),
                endTimeUnixNano: String((span.data.endTime ?? span.data.startTime) * 1000),
                status: {
                  code: span.data.status === 'ok' ? 1 : span.data.status === 'error' ? 2 : 0,
                  ...(span.data.statusMessage && {
                    message: span.data.statusMessage,
                  }),
                },
                attributes: Object.entries(span.data.attributes).map(([key, value]) => ({
                  key,
                  value: {
                    [typeof value === 'number'
                      ? 'intValue'
                      : typeof value === 'boolean'
                        ? 'boolValue'
                        : 'stringValue']: String(value),
                  },
                })),
                events: span.data.events.map(event => ({
                  timeUnixNano: String(event.timestamp * 1000),
                  name: event.name,
                  attributes: Object.entries(event.attributes).map(([key, value]) => ({
                    key,
                    value: { stringValue: String(value) },
                  })),
                })),
                links: span.data.links.map(link => ({
                  traceId: link.context.traceId,
                  spanId: link.context.spanId,
                  attributes: Object.entries(link.attributes).map(([key, value]) => ({
                    key,
                    value: { stringValue: String(value) },
                  })),
                })),
              })),
            },
          ],
        },
      ],
    }
  }

  /** Export spans in Chrome Trace Event format (for Perfetto UI). */
  toChromeTrace(): { traceEvents: Record<string, unknown>[]; metadata: Record<string, unknown> } {
    const events: Record<string, unknown>[] = []
    const completed = this.getCompletedSpans()

    for (const span of completed) {
      const startTimeUs = span.data.startTime
      const durationUs = span.durationUs ?? 0

      // Complete event (X phase)
      events.push({
        name: span.data.name,
        cat: span.data.attributes['span.type'] as string ?? 'default',
        ph: 'X',
        ts: startTimeUs,
        dur: durationUs,
        pid: 1,
        tid: 1,
        args: { ...span.data.attributes, status: span.data.status },
      })

      // Add events as instant events (i phase)
      for (const event of span.data.events) {
        events.push({
          name: event.name,
          cat: 'event',
          ph: 'i',
          ts: event.timestamp,
          pid: 1,
          tid: 1,
          args: event.attributes,
        })
      }
    }

    return {
      traceEvents: events,
      metadata: {
        'service.name': this.config.serviceName,
        span_count: completed.length,
        trace_start_time: new Date().toISOString(),
      },
    }
  }

  /** Flush completed spans to OTLP endpoint and remove them. */
  async flush(): Promise<number> {
    const completed = this.getCompletedSpans()
    if (completed.length === 0 || !this.config.otlpEndpoint) return 0

    const url = `${this.config.otlpEndpoint}/v1/traces`
    const payload = this.toOTLP()

    try {
      const response = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })

      if (response.ok) {
        // Remove flushed spans
        const flushedIds = new Set(completed.map(s => s.context.spanId))
        for (let i = this.spans.length - 1; i >= 0; i--) {
          if (flushedIds.has(this.spans[i]!.context.spanId) && this.spans[i]!.isEnded) {
            this.spans.splice(i, 1)
          }
        }
        return completed.length
      }
    } catch {
      // Swallow network errors
    }
    return 0
  }

  /** Shut down the tracer. */
  async shutdown(): Promise<void> {
    // End all active spans
    while (this.activeSpanStack.length > 0) {
      const span = this.activeSpanStack.pop()
      span?.end({ status: 'error', statusMessage: 'Tracer shutdown while span active' })
    }

    if (this.flushInterval) {
      clearInterval(this.flushInterval)
      this.flushInterval = null
    }

    await this.flush()
  }

  // -- Internal ------------------------------------------------------------

  private evictOldSpans(): void {
    if (this.spans.length <= this.config.maxSpans) return
    // Remove oldest ended spans first
    const ended = this.spans
      .map((s, i) => ({ span: s, index: i }))
      .filter(({ span }) => span.isEnded)
      .sort((a, b) => a.span.data.startTime - b.span.data.startTime)

    const toRemove = this.spans.length - this.config.maxSpans
    for (let i = 0; i < Math.min(toRemove, ended.length); i++) {
      const idx = ended[i]!.index
      this.spans.splice(idx, 1)
    }
  }

  private startFlushInterval(): void {
    this.flushInterval = setInterval(() => {
      void this.flush()
    }, this.FLUSH_INTERVAL_MS)
    if (this.flushInterval.unref) {
      this.flushInterval.unref()
    }
  }

  private spanKindToOTLP(kind: SpanKind): number {
    switch (kind) {
      case 'internal': return 1
      case 'server': return 2
      case 'client': return 3
      case 'producer': return 4
      case 'consumer': return 5
    }
  }
}
