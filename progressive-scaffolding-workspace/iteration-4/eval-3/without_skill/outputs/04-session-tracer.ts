/**
 * Session Tracer for Open-ClaudeCode Observability
 *
 * Provides a lightweight, self-contained tracing framework that mirrors the
 * project's existing span lifecycle from src/utils/telemetry/sessionTracing.ts
 * but outputs agent-readable JSON traces without requiring OpenTelemetry backends.
 *
 * Supports the same span types as the project:
 *   - interaction: user request -> Claude response cycle
 *   - llm_request: API call to the LLM with token metrics
 *   - tool: tool invocation with permission tracking
 *   - tool.blocked_on_user: waiting for user permission decision
 *   - tool.execution: actual tool execution time
 *   - hook: PreToolUse / PostToolUse hook execution
 *
 * Usage by AI agents:
 *   const tracer = createSessionTracer('session-abc123')
 *
 *   const interactionId = tracer.startInteraction('explain this code')
 *   const llmId = tracer.startLLMRequest('claude-sonnet-4')
 *   // ... API call happens ...
 *   tracer.endLLMRequest(llmId, { inputTokens: 1500, outputTokens: 800, ttftMs: 340, success: true })
 *   tracer.endInteraction(interactionId)
 *
 *   // Export the full trace for analysis
 *   const trace = tracer.exportTrace()
 */

// ---------- Types ----------

export type SpanType =
  | 'interaction'
  | 'llm_request'
  | 'tool'
  | 'tool.blocked_on_user'
  | 'tool.execution'
  | 'hook'

export interface SpanData {
  spanId: string
  parentSpanId?: string
  spanType: SpanType
  name: string
  startTime: string
  endTime?: string
  durationMs?: number
  status: 'started' | 'ok' | 'error'
  attributes: Record<string, string | number | boolean>
  events: SpanEvent[]
}

export interface SpanEvent {
  name: string
  timestamp: string
  attributes: Record<string, string | number | boolean>
}

export interface LLMRequestMetrics {
  inputTokens?: number
  outputTokens?: number
  cacheReadTokens?: number
  cacheCreationTokens?: number
  ttftMs?: number
  ttltMs?: number
  success?: boolean
  statusCode?: number
  error?: string
  attempt?: number
  modelResponse?: string
  hasToolCall?: boolean
}

export interface ToolMetrics {
  toolName: string
  success?: boolean
  error?: string
  resultTokens?: number
}

export interface PermissionMetrics {
  decision?: string
  source?: string
}

export interface HookMetrics {
  hookEvent: string
  hookName: string
  numSuccess?: number
  numBlocking?: number
  numNonBlockingError?: number
  numCancelled?: number
}

export interface TraceExport {
  sessionId: string
  exportedAt: string
  totalSpans: number
  completedSpans: number
  errorSpans: number
  activeSpans: number
  spans: SpanData[]
}

// ---------- Span TTL (mirrors sessionTracing.ts SPAN_TTL_MS) ----------

const SPAN_TTL_MS = 30 * 60 * 1000 // 30 minutes

// ---------- Tracer ----------

let idCounter = 0

function nextId(): string {
  return `span_${++idCounter}_${Date.now().toString(36)}`
}

export function createSessionTracer(sessionId: string) {
  const spans = new Map<string, SpanData>()
  const completed: SpanData[] = []

  function createSpan(
    spanType: SpanType,
    name: string,
    parentSpanId: string | undefined,
    attributes: Record<string, string | number | boolean> = {},
  ): string {
    const spanId = nextId()
    const span: SpanData = {
      spanId,
      parentSpanId,
      spanType,
      name,
      startTime: new Date().toISOString(),
      status: 'started',
      attributes,
      events: [],
    }
    spans.set(spanId, span)
    return spanId
  }

  function endSpan(spanId: string, status: 'ok' | 'error' = 'ok', extraAttrs?: Record<string, string | number | boolean>): void {
    const span = spans.get(spanId)
    if (!span) return

    span.endTime = new Date().toISOString()
    span.durationMs = new Date(span.endTime).getTime() - new Date(span.startTime).getTime()
    span.status = status
    if (extraAttrs) {
      span.attributes = { ...span.attributes, ...extraAttrs }
    }
    spans.delete(spanId)
    completed.push(span)
  }

  // --- Interaction spans ---

  function startInteraction(userPrompt: string): string {
    return createSpan('interaction', 'claude_code.interaction', undefined, {
      user_prompt_length: userPrompt.length,
      user_prompt: process.env.OTEL_LOG_USER_PROMPTS === '1' ? userPrompt : '<REDACTED>',
    })
  }

  function endInteraction(spanId: string): void {
    endSpan(spanId)
  }

  // --- LLM request spans ---

  function startLLMRequest(model: string, parentSpanId?: string): string {
    return createSpan('llm_request', 'claude_code.llm_request', parentSpanId, {
      model,
    })
  }

  function endLLMRequest(spanId: string, metrics: LLMRequestMetrics): void {
    const attrs: Record<string, string | number | boolean> = {}
    if (metrics.inputTokens !== undefined) attrs.input_tokens = metrics.inputTokens
    if (metrics.outputTokens !== undefined) attrs.output_tokens = metrics.outputTokens
    if (metrics.cacheReadTokens !== undefined) attrs.cache_read_tokens = metrics.cacheReadTokens
    if (metrics.cacheCreationTokens !== undefined) attrs.cache_creation_tokens = metrics.cacheCreationTokens
    if (metrics.ttftMs !== undefined) attrs.ttft_ms = metrics.ttftMs
    if (metrics.ttltMs !== undefined) attrs.ttlt_ms = metrics.ttltMs
    if (metrics.statusCode !== undefined) attrs.status_code = metrics.statusCode
    if (metrics.error !== undefined) attrs.error = metrics.error
    if (metrics.attempt !== undefined) attrs.attempt = metrics.attempt
    if (metrics.hasToolCall !== undefined) attrs.has_tool_call = metrics.hasToolCall
    endSpan(spanId, metrics.success === false ? 'error' : 'ok', attrs)
  }

  // --- Tool spans ---

  function startTool(toolName: string, parentSpanId?: string): string {
    return createSpan('tool', `claude_code.tool.${toolName}`, parentSpanId, {
      tool_name: toolName,
    })
  }

  function endTool(spanId: string, metrics: ToolMetrics): void {
    const attrs: Record<string, string | number | boolean> = {}
    if (metrics.success !== undefined) attrs.success = metrics.success
    if (metrics.error !== undefined) attrs.error = metrics.error
    if (metrics.resultTokens !== undefined) attrs.result_tokens = metrics.resultTokens
    endSpan(spanId, metrics.success === false ? 'error' : 'ok', attrs)
  }

  // --- Permission wait spans ---

  function startPermissionWait(toolName: string, parentSpanId?: string): string {
    return createSpan('tool.blocked_on_user', 'claude_code.tool.blocked_on_user', parentSpanId, {
      tool_name: toolName,
    })
  }

  function endPermissionWait(spanId: string, metrics: PermissionMetrics): void {
    const attrs: Record<string, string | number | boolean> = {}
    if (metrics.decision) attrs.decision = metrics.decision
    if (metrics.source) attrs.source = metrics.source
    endSpan(spanId, 'ok', attrs)
  }

  // --- Tool execution spans ---

  function startToolExecution(toolName: string, parentSpanId?: string): string {
    return createSpan('tool.execution', 'claude_code.tool.execution', parentSpanId, {
      tool_name: toolName,
    })
  }

  function endToolExecution(spanId: string, success: boolean, error?: string): void {
    endSpan(spanId, success ? 'ok' : 'error', {
      ...(error ? { error } : {}),
    })
  }

  // --- Hook spans ---

  function startHook(hookEvent: string, hookName: string, parentSpanId?: string): string {
    return createSpan('hook', 'claude_code.hook', parentSpanId, {
      hook_event: hookEvent,
      hook_name: hookName,
    })
  }

  function endHook(spanId: string, metrics: HookMetrics): void {
    const attrs: Record<string, string | number | boolean> = {}
    if (metrics.numSuccess !== undefined) attrs.num_success = metrics.numSuccess
    if (metrics.numBlocking !== undefined) attrs.num_blocking = metrics.numBlocking
    if (metrics.numNonBlockingError !== undefined) attrs.num_non_blocking_error = metrics.numNonBlockingError
    if (metrics.numCancelled !== undefined) attrs.num_cancelled = metrics.numCancelled
    endSpan(spanId, 'ok', attrs)
  }

  // --- Events on spans ---

  function addEvent(spanId: string, name: string, attributes: Record<string, string | number | boolean> = {}): void {
    const span = spans.get(spanId)
    if (!span) return
    span.events.push({
      name,
      timestamp: new Date().toISOString(),
      attributes,
    })
  }

  // --- Cleanup stale spans (mirrors sessionTracing.ts cleanup) ---

  function evictStaleSpans(): number {
    const cutoff = Date.now() - SPAN_TTL_MS
    let evicted = 0
    for (const [spanId, span] of spans) {
      const startMs = new Date(span.startTime).getTime()
      if (startMs < cutoff) {
        endSpan(spanId, 'error', { evicted: true })
        evicted++
      }
    }
    return evicted
  }

  // --- Export ---

  function exportTrace(): TraceExport {
    const allSpans = [...completed, ...spans.values()]
    return {
      sessionId,
      exportedAt: new Date().toISOString(),
      totalSpans: allSpans.length,
      completedSpans: completed.length,
      errorSpans: allSpans.filter(s => s.status === 'error').length,
      activeSpans: spans.size,
      spans: allSpans,
    }
  }

  /** Get a summary suitable for quick agent inspection. */
  function summary(): {
    sessionId: string
    activeSpanCount: number
    completedSpanCount: number
    errorCount: number
    spanTypes: Record<string, number>
    avgDurationByType: Record<string, number>
  } {
    const allSpans = [...completed, ...spans.values()]
    const spanTypes: Record<string, number> = {}
    const durationsByType: Record<string, number[]> = {}

    for (const span of allSpans) {
      spanTypes[span.spanType] = (spanTypes[span.spanType] || 0) + 1
      if (span.durationMs !== undefined) {
        if (!durationsByType[span.spanType]) durationsByType[span.spanType] = []
        durationsByType[span.spanType].push(span.durationMs)
      }
    }

    const avgDurationByType: Record<string, number> = {}
    for (const [type, durations] of Object.entries(durationsByType)) {
      avgDurationByType[type] = Math.round(durations.reduce((a, b) => a + b, 0) / durations.length)
    }

    return {
      sessionId,
      activeSpanCount: spans.size,
      completedSpanCount: completed.length,
      errorCount: allSpans.filter(s => s.status === 'error').length,
      spanTypes,
      avgDurationByType,
    }
  }

  return {
    startInteraction,
    endInteraction,
    startLLMRequest,
    endLLMRequest,
    startTool,
    endTool,
    startPermissionWait,
    endPermissionWait,
    startToolExecution,
    endToolExecution,
    startHook,
    endHook,
    addEvent,
    evictStaleSpans,
    exportTrace,
    summary,
  }
}
