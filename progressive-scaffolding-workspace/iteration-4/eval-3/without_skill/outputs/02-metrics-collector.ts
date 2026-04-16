/**
 * Metrics Collector for Open-ClaudeCode Observability
 *
 * Provides in-process metric primitives (counters, histograms, gauges) that
 * mirror the project's OpenTelemetry MeterProvider usage but are lightweight
 * and agent-readable without requiring an OTLP backend.
 *
 * Aligned with existing metrics from:
 *   - src/utils/telemetry/instrumentation.ts (MeterProvider, PeriodicExportingMetricReader)
 *   - src/utils/telemetry/bigqueryExporter.ts (BigQueryMetricsExporter)
 *   - src/services/analytics/datadog.ts (trackDatadogEvent)
 *
 * Usage by AI agents:
 *   const metrics = createMetricsCollector('claude-code')
 *   metrics.counter('api.requests').inc(1, { model: 'claude-sonnet-4', status: '200' })
 *   metrics.histogram('llm.ttft_ms').record(342, { model: 'claude-sonnet-4' })
 *   metrics.gauge('process.heap_used').set(128_000_000)
 *   console.log(metrics.snapshot())  // JSON-serializable snapshot
 */

// ---------- Types ----------

export type MetricValue = number

export interface MetricPoint {
  name: string
  type: 'counter' | 'histogram' | 'gauge'
  value: MetricValue
  labels: Record<string, string>
  timestamp: string
}

export interface HistogramSummary {
  count: number
  sum: number
  min: number
  max: number
  mean: number
  p50: number
  p95: number
  p99: number
}

export interface MetricSnapshot {
  collector: string
  capturedAt: string
  counters: Array<{ name: string; value: number; labels: Record<string, string> }>
  gauges: Array<{ name: string; value: number; labels: Record<string, string> }>
  histograms: Array<{
    name: string
    labels: Record<string, string>
    summary: HistogramSummary
  }>
  /** Process-level resource metrics included automatically. */
  process: {
    uptimeSeconds: number
    rssBytes: number
    heapTotalBytes: number
    heapUsedBytes: number
    cpuUserMicros: number
    cpuSystemMicros: number
  }
}

// ---------- Counter ----------

class Counter {
  private value = 0
  constructor(
    readonly name: string,
    readonly labels: Record<string, string>,
  ) {}

  inc(delta = 1): void {
    this.value += delta
  }

  get(): number {
    return this.value
  }
}

// ---------- Gauge ----------

class Gauge {
  private value = 0
  constructor(
    readonly name: string,
    readonly labels: Record<string, string>,
  ) {}

  set(val: number): void {
    this.value = val
  }

  get(): number {
    return this.value
  }
}

// ---------- Histogram ----------

class Histogram {
  private samples: number[] = []
  constructor(
    readonly name: string,
    readonly labels: Record<string, string>,
    private readonly maxSamples = 10_000,
  ) {}

  record(val: number): void {
    if (this.samples.length >= this.maxSamples) {
      // Evict oldest half (amortized O(1) like Perfetto evictOldestEvents)
      this.samples = this.samples.slice(this.maxSamples / 2)
    }
    this.samples.push(val)
  }

  summary(): HistogramSummary {
    const sorted = [...this.samples].sort((a, b) => a - b)
    const count = sorted.length
    if (count === 0) {
      return { count: 0, sum: 0, min: 0, max: 0, mean: 0, p50: 0, p95: 0, p99: 0 }
    }
    const sum = sorted.reduce((a, b) => a + b, 0)
    const pct = (p: number) => sorted[Math.min(Math.floor(count * p), count - 1)]
    return {
      count,
      sum,
      min: sorted[0],
      max: sorted[count - 1],
      mean: sum / count,
      p50: pct(0.5),
      p95: pct(0.95),
      p99: pct(0.99),
    }
  }
}

// ---------- Collector ----------

function labelKey(labels: Record<string, string>): string {
  return Object.entries(labels)
    .sort(([a], [b]) => a.localeCompare(b))
    .map(([k, v]) => `${k}=${v}`)
    .join(',')
}

export function createMetricsCollector(collectorName: string) {
  const counters = new Map<string, Counter>()
  const gauges = new Map<string, Gauge>()
  const histograms = new Map<string, Histogram>()

  function mkKey(name: string, labels: Record<string, string>): string {
    return `${name}|${labelKey(labels)}`
  }

  function counter(name: string, labels: Record<string, string> = {}): Counter {
    const key = mkKey(name, labels)
    let c = counters.get(key)
    if (!c) {
      c = new Counter(name, labels)
      counters.set(key, c)
    }
    return c
  }

  function gauge(name: string, labels: Record<string, string> = {}): Gauge {
    const key = mkKey(name, labels)
    let g = gauges.get(key)
    if (!g) {
      g = new Gauge(name, labels)
      gauges.set(key, g)
    }
    return g
  }

  function histogram(name: string, labels: Record<string, string> = {}): Histogram {
    const key = mkKey(name, labels)
    let h = histograms.get(key)
    if (!h) {
      h = new Histogram(name, labels)
      histograms.set(key, h)
    }
    return h
  }

  function snapshot(): MetricSnapshot {
    const mem = process.memoryUsage()
    const cpu = process.cpuUsage()

    return {
      collector: collectorName,
      capturedAt: new Date().toISOString(),
      counters: Array.from(counters.values()).map(c => ({
        name: c.name,
        value: c.get(),
        labels: c.labels,
      })),
      gauges: Array.from(gauges.values()).map(g => ({
        name: g.name,
        value: g.get(),
        labels: g.labels,
      })),
      histograms: Array.from(histograms.values()).map(h => ({
        name: h.name,
        labels: h.labels,
        summary: h.summary(),
      })),
      process: {
        uptimeSeconds: process.uptime(),
        rssBytes: mem.rss,
        heapTotalBytes: mem.heapTotal,
        heapUsedBytes: mem.heapUsed,
        cpuUserMicros: cpu.user,
        cpuSystemMicros: cpu.system,
      },
    }
  }

  /** Reset all metrics (for testing). */
  function reset(): void {
    counters.clear()
    gauges.clear()
    histograms.clear()
  }

  return { counter, gauge, histogram, snapshot, reset }
}

// ---------- Pre-built CLI-specific metric helpers ----------

/**
 * Metrics tailored to the Open-ClaudeCode CLI session lifecycle.
 * Covers: API calls, tool executions, token usage, spans, permissions.
 */
export function createCliMetrics() {
  const m = createMetricsCollector('claude-code-cli')

  return {
    ...m,

    // --- LLM API metrics ---
    recordApiCall(params: {
      model: string
      status: number
      durationMs: number
      inputTokens?: number
      outputTokens?: number
      cacheReadTokens?: number
      cacheCreationTokens?: number
      ttftMs?: number
      success: boolean
    }) {
      const labels = { model: params.model, status: String(params.status) }
      m.counter('api.requests', labels).inc()
      m.histogram('api.duration_ms', labels).record(params.durationMs)
      if (params.inputTokens !== undefined) {
        m.histogram('api.input_tokens', labels).record(params.inputTokens)
      }
      if (params.outputTokens !== undefined) {
        m.histogram('api.output_tokens', labels).record(params.outputTokens)
      }
      if (params.ttftMs !== undefined) {
        m.histogram('api.ttft_ms', labels).record(params.ttftMs)
      }
      if (params.cacheReadTokens !== undefined) {
        m.counter('api.cache_read_tokens', labels).inc(params.cacheReadTokens)
      }
      if (params.cacheCreationTokens !== undefined) {
        m.counter('api.cache_creation_tokens', labels).inc(params.cacheCreationTokens)
      }
      if (!params.success) {
        m.counter('api.errors', labels).inc()
      }
    },

    // --- Tool execution metrics ---
    recordToolCall(params: {
      toolName: string
      durationMs: number
      success: boolean
      resultTokens?: number
    }) {
      // Sanitize MCP tool names (mirrors datadog.ts normalization)
      const sanitizedTool = params.toolName.startsWith('mcp__') ? 'mcp' : params.toolName
      const labels = { tool: sanitizedTool }
      m.counter('tool.calls', labels).inc()
      m.histogram('tool.duration_ms', labels).record(params.durationMs)
      if (!params.success) {
        m.counter('tool.errors', labels).inc()
      }
      if (params.resultTokens !== undefined) {
        m.counter('tool.result_tokens', labels).inc(params.resultTokens)
      }
    },

    // --- Permission metrics ---
    recordPermissionDecision(params: {
      toolName: string
      decision: 'granted' | 'denied' | 'cancelled'
      source: string
    }) {
      const labels = { tool: params.toolName, decision: params.decision, source: params.source }
      m.counter('permission.decisions', labels).inc()
    },

    // --- Span/tracing metrics ---
    recordSpan(params: {
      spanType: string
      durationMs: number
      ended: boolean
    }) {
      const labels = { span_type: params.spanType, ended: String(params.ended) }
      m.counter('spans.total', labels).inc()
      if (params.ended) {
        m.histogram('spans.duration_ms', { span_type: params.spanType }).record(params.durationMs)
      }
    },
  }
}
