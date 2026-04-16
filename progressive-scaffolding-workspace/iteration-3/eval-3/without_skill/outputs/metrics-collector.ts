/**
 * Metrics Collector for Open-ClaudeCode
 *
 * Collects runtime metrics aligned with the project's existing OpenTelemetry
 * MeterProvider (src/utils/telemetry/instrumentation.ts). Metrics mirror the
 * naming conventions already used in the BigQuery exporter
 * (src/utils/telemetry/bigqueryExporter.ts) and the analytics metadata
 * (src/services/analytics/metadata.ts ProcessMetrics).
 *
 * Metric categories:
 *   - API/Latency: LLM request durations, TTFT, TTLT, token throughput
 *   - Tool usage: Invocation counts, success/failure rates, durations
 *   - System: Memory (rss, heapTotal, heapUsed), CPU%, event loop lag
 *   - Session: Interaction counts, context window utilization
 *   - Cost: Token-based cost estimation per model
 *
 * Usage:
 *   const collector = new MetricsCollector()
 *   collector.recordLLMRequest({ model: 'claude-sonnet-4-20250514', ttftMs: 340, ... })
 *   collector.recordToolInvocation({ tool: 'Bash', durationMs: 120, success: true })
 *
 * Export formats:
 *   - OTLP JSON to a collector endpoint
 *   - Prometheus exposition format (pull)
 *   - JSON snapshot (for health checks / debugging)
 */

import { createServer, type IncomingMessage, type ServerResponse } from 'http'

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type LLMRequestMetrics = {
  model: string
  ttftMs?: number
  ttltMs?: number
  inputTokens?: number
  outputTokens?: number
  cacheReadTokens?: number
  cacheCreationTokens?: number
  success: boolean
  error?: string
  attempt?: number
  querySource?: string
}

export type ToolInvocationMetrics = {
  tool: string
  durationMs: number
  success: boolean
  error?: string
  resultTokens?: number
}

export type SystemMetrics = {
  rss: number
  heapTotal: number
  heapUsed: number
  external: number
  arrayBuffers: number
  cpuPercent: number | undefined
  uptime: number
  eventLoopLagMs: number
}

export type InteractionMetrics = {
  durationMs: number
  toolCallCount: number
  llmRequestCount: number
  totalInputTokens: number
  totalOutputTokens: number
  userPromptLength: number
}

export type MetricDataPoint = {
  name: string
  value: number
  timestamp: string
  labels: Record<string, string>
  type: 'counter' | 'gauge' | 'histogram'
}

// ---------------------------------------------------------------------------
// MetricsCollector
// ---------------------------------------------------------------------------

export class MetricsCollector {
  // Counters
  private readonly counters = new Map<string, number>()
  // Gauges (latest value)
  private readonly gauges = new Map<string, number>()
  // Histograms (samples for percentile calculation)
  private readonly histograms = new Map<string, number[]>()
  // Labels per metric
  private readonly metricLabels = new Map<string, Record<string, string>>()
  // Prometheus server
  private prometheusServer: ReturnType<typeof createServer> | null = null
  // Flush interval
  private flushInterval: ReturnType<typeof setInterval> | null = null
  private readonly FLUSH_INTERVAL_MS = 60_000
  // OTLP endpoint
  private readonly otlpEndpoint: string | null

  constructor(config?: { otlpEndpoint?: string }) {
    this.otlpEndpoint =
      config?.otlpEndpoint ??
      process.env.OTEL_EXPORTER_OTLP_ENDPOINT ??
      null

    this.startFlushInterval()
  }

  // -- High-level recorders ------------------------------------------------

  recordLLMRequest(metrics: LLMRequestMetrics): void {
    const modelLabel = this.sanitizeModel(metrics.model)
    const labels = { model: modelLabel, source: metrics.querySource ?? 'unknown' }

    // Counters
    this.incrementCounter('llm_requests_total', labels)
    this.incrementCounter(
      metrics.success ? 'llm_requests_success_total' : 'llm_requests_failure_total',
      labels,
    )
    if (metrics.attempt && metrics.attempt > 1) {
      this.incrementCounter('llm_request_retries_total', labels)
    }

    // Histograms
    if (metrics.ttftMs !== undefined) {
      this.observeHistogram('llm_ttft_ms', metrics.ttftMs, labels)
    }
    if (metrics.ttltMs !== undefined) {
      this.observeHistogram('llm_ttlt_ms', metrics.ttltMs, labels)
    }

    // Token counters
    if (metrics.inputTokens !== undefined) {
      this.incrementCounter('llm_input_tokens_total', labels, metrics.inputTokens)
    }
    if (metrics.outputTokens !== undefined) {
      this.incrementCounter('llm_output_tokens_total', labels, metrics.outputTokens)
    }
    if (metrics.cacheReadTokens !== undefined) {
      this.incrementCounter('llm_cache_read_tokens_total', labels, metrics.cacheReadTokens)
    }
    if (metrics.cacheCreationTokens !== undefined) {
      this.incrementCounter(
        'llm_cache_creation_tokens_total',
        labels,
        metrics.cacheCreationTokens,
      )
    }
  }

  recordToolInvocation(metrics: ToolInvocationMetrics): void {
    const labels = {
      tool: metrics.tool.startsWith('mcp__') ? 'mcp_tool' : metrics.tool,
      success: String(metrics.success),
    }

    this.incrementCounter('tool_invocations_total', labels)
    this.observeHistogram('tool_duration_ms', metrics.durationMs, labels)

    if (metrics.resultTokens !== undefined) {
      this.incrementCounter('tool_result_tokens_total', labels, metrics.resultTokens)
    }

    if (metrics.error) {
      this.incrementCounter('tool_errors_total', { ...labels, error: 'true' })
    }
  }

  recordSystemMetrics(): SystemMetrics {
    const mem = process.memoryUsage()
    const now = Date.now()

    // Event loop lag measurement
    const start = performance.now()
    let lag = 0
    setImmediate(() => {
      lag = performance.now() - start
    })

    // CPU estimation (same approach as metadata.ts buildProcessMetrics)
    const cpu = process.cpuUsage()
    const wallMs = performance.now()
    let cpuPercent: number | undefined
    if (this._prevCpuUsage && this._prevWallMs) {
      const wallDelta = wallMs - this._prevWallMs
      if (wallDelta > 0) {
        const userDelta = cpu.user - this._prevCpuUsage.user
        const sysDelta = cpu.system - this._prevCpuUsage.system
        cpuPercent = ((userDelta + sysDelta) / (wallDelta * 1000)) * 100
      }
    }
    this._prevCpuUsage = cpu
    this._prevWallMs = wallMs

    const metrics: SystemMetrics = {
      rss: mem.rss,
      heapTotal: mem.heapTotal,
      heapUsed: mem.heapUsed,
      external: mem.external,
      arrayBuffers: mem.arrayBuffers,
      cpuPercent,
      uptime: process.uptime(),
      eventLoopLagMs: lag,
    }

    // Record gauges
    const labels: Record<string, string> = {}
    this.setGauge('process_rss_bytes', mem.rss, labels)
    this.setGauge('process_heap_total_bytes', mem.heapTotal, labels)
    this.setGauge('process_heap_used_bytes', mem.heapUsed, labels)
    this.setGauge('process_external_bytes', mem.external, labels)
    this.setGauge('process_uptime_seconds', process.uptime(), labels)
    if (cpuPercent !== undefined) {
      this.setGauge('process_cpu_percent', cpuPercent, labels)
    }
    this.setGauge('event_loop_lag_ms', lag, labels)

    return metrics
  }

  recordInteraction(metrics: InteractionMetrics): void {
    const labels: Record<string, string> = {}
    this.incrementCounter('interactions_total', labels)
    this.observeHistogram('interaction_duration_ms', metrics.durationMs, labels)
    this.incrementCounter('interaction_tool_calls_total', labels, metrics.toolCallCount)
    this.incrementCounter('interaction_llm_requests_total', labels, metrics.llmRequestCount)
    this.incrementCounter('interaction_input_tokens_total', labels, metrics.totalInputTokens)
    this.incrementCounter('interaction_output_tokens_total', labels, metrics.totalOutputTokens)
  }

  // -- Export --------------------------------------------------------------

  /** Get a JSON snapshot of all current metrics (for health checks). */
  getSnapshot(): {
    counters: Record<string, { value: number; labels: Record<string, string> }>
    gauges: Record<string, { value: number; labels: Record<string, string> }>
    histograms: Record<string, {
      samples: number
      min: number
      max: number
      mean: number
      p50: number
      p95: number
      p99: number
      labels: Record<string, string>
    }>
    timestamp: string
  } {
    const counters: Record<string, { value: number; labels: Record<string, string> }> = {}
    for (const [key, value] of this.counters) {
      counters[key] = { value, labels: this.metricLabels.get(key) ?? {} }
    }

    const gauges: Record<string, { value: number; labels: Record<string, string> }> = {}
    for (const [key, value] of this.gauges) {
      gauges[key] = { value, labels: this.metricLabels.get(key) ?? {} }
    }

    const histograms: Record<string, {
      samples: number
      min: number
      max: number
      mean: number
      p50: number
      p95: number
      p99: number
      labels: Record<string, string>
    }> = {}
    for (const [key, samples] of this.histograms) {
      const sorted = [...samples].sort((a, b) => a - b)
      const sum = sorted.reduce((acc, v) => acc + v, 0)
      histograms[key] = {
        samples: sorted.length,
        min: sorted[0] ?? 0,
        max: sorted[sorted.length - 1] ?? 0,
        mean: sorted.length > 0 ? sum / sorted.length : 0,
        p50: this.percentile(sorted, 0.5),
        p95: this.percentile(sorted, 0.95),
        p99: this.percentile(sorted, 0.99),
        labels: this.metricLabels.get(key) ?? {},
      }
    }

    return { counters, gauges, histograms, timestamp: new Date().toISOString() }
  }

  /** Generate Prometheus exposition text format. */
  toPrometheus(): string {
    const lines: string[] = []

    // Counters
    for (const [key, value] of this.counters) {
      const labels = this.metricLabels.get(key) ?? {}
      const labelStr = this.formatPrometheusLabels(labels)
      lines.push(`# TYPE ${key} counter`)
      lines.push(`${key}${labelStr} ${value}`)
    }

    // Gauges
    for (const [key, value] of this.gauges) {
      const labels = this.metricLabels.get(key) ?? {}
      const labelStr = this.formatPrometheusLabels(labels)
      lines.push(`# TYPE ${key} gauge`)
      lines.push(`${key}${labelStr} ${value}`)
    }

    // Histograms
    for (const [key, samples] of this.histograms) {
      const labels = this.metricLabels.get(key) ?? {}
      const labelStr = this.formatPrometheusLabels(labels)
      const sorted = [...samples].sort((a, b) => a - b)
      const sum = sorted.reduce((acc, v) => acc + v, 0)

      lines.push(`# TYPE ${key} histogram`)
      // Buckets: 10, 50, 100, 250, 500, 1000, 2500, 5000, 10000, +Inf
      const buckets = [10, 50, 100, 250, 500, 1000, 2500, 5000, 10000]
      let count = 0
      for (const bucket of buckets) {
        while (count < sorted.length && sorted[count]! <= bucket) count++
        lines.push(`${key}_bucket{le="${bucket}",${labelStr.slice(1, -1)}} ${count}`)
      }
      lines.push(`${key}_bucket{le="+Inf",${labelStr.slice(1, -1)}} ${sorted.length}`)
      lines.push(`${key}_sum${labelStr} ${sum}`)
      lines.push(`${key}_count${labelStr} ${sorted.length}`)
    }

    return lines.join('\n') + '\n'
  }

  /** Start an HTTP server for Prometheus scraping. */
  startPrometheusEndpoint(port: number = 9464): void {
    this.prometheusServer = createServer(
      (req: IncomingMessage, res: ServerResponse) => {
        if (req.url === '/metrics') {
          res.writeHead(200, { 'Content-Type': 'text/plain; version=0.0.4' })
          res.end(this.toPrometheus())
        } else {
          res.writeHead(404)
          res.end()
        }
      },
    )
    this.prometheusServer.listen(port, () => {
      // Server started
    })
  }

  /** Shut down the collector and release resources. */
  async shutdown(): Promise<void> {
    if (this.flushInterval) {
      clearInterval(this.flushInterval)
      this.flushInterval = null
    }
    if (this.prometheusServer) {
      await new Promise<void>(resolve => this.prometheusServer!.close(() => resolve()))
      this.prometheusServer = null
    }
  }

  // -- Internal ------------------------------------------------------------

  private _prevCpuUsage: NodeJS.CpuUsage | null = null
  private _prevWallMs: number = 0

  private incrementCounter(
    name: string,
    labels: Record<string, string>,
    amount: number = 1,
  ): void {
    const key = this.metricKey(name, labels)
    const current = this.counters.get(key) ?? 0
    this.counters.set(key, current + amount)
    this.metricLabels.set(key, labels)
  }

  private setGauge(
    name: string,
    value: number,
    labels: Record<string, string>,
  ): void {
    const key = this.metricKey(name, labels)
    this.gauges.set(key, value)
    this.metricLabels.set(key, labels)
  }

  private observeHistogram(
    name: string,
    value: number,
    labels: Record<string, string>,
  ): void {
    const key = this.metricKey(name, labels)
    let samples = this.histograms.get(key)
    if (!samples) {
      samples = []
      this.histograms.set(key, samples)
    }
    samples.push(value)
    // Cap at 10000 samples per histogram to bound memory
    if (samples.length > 10000) {
      samples.splice(0, samples.length - 10000)
    }
    this.metricLabels.set(key, labels)
  }

  private metricKey(name: string, labels: Record<string, string>): string {
    const sortedLabels = Object.entries(labels)
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([k, v]) => `${k}=${v}`)
      .join(',')
    return `${name}{${sortedLabels}}`
  }

  private percentile(sorted: number[], p: number): number {
    if (sorted.length === 0) return 0
    const idx = Math.ceil(p * sorted.length) - 1
    return sorted[Math.max(0, idx)]!
  }

  private sanitizeModel(model: string): string {
    // Reduce cardinality: strip fine-grained date suffixes
    return model.replace(/\[\d+m\]$/i, '').replace(/^claude-/, '')
  }

  private formatPrometheusLabels(labels: Record<string, string>): string {
    const entries = Object.entries(labels)
    if (entries.length === 0) return ''
    const pairs = entries.map(([k, v]) => `${k}="${v}"`).join(',')
    return `{${pairs}}`
  }

  private startFlushInterval(): void {
    // Periodically collect system metrics and flush to OTLP
    this.flushInterval = setInterval(() => {
      this.recordSystemMetrics()
      if (this.otlpEndpoint) {
        this.flushToOTLP()
      }
    }, this.FLUSH_INTERVAL_MS)
    if (this.flushInterval.unref) {
      this.flushInterval.unref()
    }
  }

  private async flushToOTLP(): Promise<void> {
    if (!this.otlpEndpoint) return

    const snapshot = this.getSnapshot()
    const url = `${this.otlpEndpoint}/v1/metrics`

    try {
      await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          resourceMetrics: [
            {
              resource: {
                attributes: [
                  { key: 'service.name', value: { stringValue: 'claude-code-monitor' } },
                ],
              },
              scopeMetrics: [
                {
                  scope: { name: 'observability-metrics' },
                  metrics: [
                    ...Object.entries(snapshot.counters).map(([key, data]) => ({
                      name: key.split('{')[0]!,
                      data: {
                        dataPoints: [
                          {
                            asInt: data.value,
                            timeUnixNano: String(Date.now() * 1_000_000),
                            attributes: Object.entries(data.labels).map(([k, v]) => ({
                              key: k,
                              value: { stringValue: v },
                            })),
                          },
                        ],
                        isMonotonic: true,
                        aggregationTemporality: 2,
                      },
                    })),
                    ...Object.entries(snapshot.gauges).map(([key, data]) => ({
                      name: key.split('{')[0]!,
                      data: {
                        dataPoints: [
                          {
                            asDouble: data.value,
                            timeUnixNano: String(Date.now() * 1_000_000),
                            attributes: Object.entries(data.labels).map(([k, v]) => ({
                              key: k,
                              value: { stringValue: v },
                            })),
                          },
                        ],
                      },
                    })),
                  ],
                },
              ],
            },
          ],
        }),
      })
    } catch {
      // Swallow network errors
    }
  }
}
