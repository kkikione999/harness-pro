#!/bin/bash
# scaffold/trace-query-pipeline.sh
# Analyzes the query pipeline (QueryEngine -> query -> tools) and generates
# a tracing instrumentation plan with span definitions and correlation IDs.
# Does NOT modify source files - generates analysis and templates.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
SRC_DIR="${PROJECT_ROOT}/src"
OUTPUT_DIR="${PROJECT_ROOT}/.scaffolding/observability"

mkdir -p "$OUTPUT_DIR"

echo "=== Query Pipeline Trace Analyzer ==="
echo ""

PLAN_FILE="${OUTPUT_DIR}/pipeline-trace-plan.txt"
TEMPLATE_FILE="${OUTPUT_DIR}/pipeline-trace-template.ts"

# Analyze pipeline entry points
echo "Phase 1: Identifying pipeline stages..."
echo ""

{
    echo "Query Pipeline Trace Instrumentation Plan"
    echo "=========================================="
    echo ""
    echo "Pipeline Flow:"
    echo "  User Input -> REPL.tsx -> QueryEngine.ts -> query.ts -> Tool Dispatch -> Result"
    echo ""

    # Stage 1: REPL (entry point)
    echo "--- Stage 1: REPL Entry (src/screens/REPL.tsx) ---"
    if [[ -f "$SRC_DIR/screens/REPL.tsx" ]]; then
        repl_lines=$(wc -l < "$SRC_DIR/screens/REPL.tsx" | tr -d ' ')
        echo "  File: ${repl_lines} lines"
        # Find the query dispatch point
        if grep -qE "QueryEngine|queryEngine" "$SRC_DIR/screens/REPL.tsx" 2>/dev/null; then
            echo "  [SPAN:repl.input] Start trace when user submits query"
            echo "  Instrument: Find onSubmit/queryDispatch handler"
            grep -nE "QueryEngine|handleSubmit|onSubmit|sendMessage" "$SRC_DIR/screens/REPL.tsx" 2>/dev/null | head -5 | sed 's/^/    /'
        fi
    fi
    echo ""

    # Stage 2: QueryEngine (orchestrator)
    echo "--- Stage 2: QueryEngine (src/QueryEngine.ts) ---"
    if [[ -f "$SRC_DIR/QueryEngine.ts" ]]; then
        qe_lines=$(wc -l < "$SRC_DIR/QueryEngine.ts" | tr -d ' ')
        echo "  File: ${qe_lines} lines"
        echo "  [SPAN:query.engine] QueryEngine.runQuery() entry"
        echo "  [SPAN:query.loop] Each turn of the query loop"
        echo "  [SPAN:query.tool_dispatch] Tool dispatch within turn"
        echo "  Key methods:"
        grep -nE "async\s+\w+\s*\(" "$SRC_DIR/QueryEngine.ts" 2>/dev/null | head -10 | sed 's/^/    /'
    fi
    echo ""

    # Stage 3: query.ts (single API turn)
    echo "--- Stage 3: Query (src/query.ts) ---"
    if [[ -f "$SRC_DIR/query.ts" ]]; then
        q_lines=$(wc -l < "$SRC_DIR/query.ts" | tr -d ' ')
        echo "  File: ${q_lines} lines"
        echo "  [SPAN:query.api_call] Single API turn to Claude"
        echo "  [SPAN:query.stream] Streaming response processing"
        echo "  Key exports:"
        grep -nE "export\s+(async\s+)?function" "$SRC_DIR/query.ts" 2>/dev/null | head -10 | sed 's/^/    /'
    fi
    echo ""

    # Stage 4: Tool dispatch
    echo "--- Stage 4: Tool Dispatch (src/Tool.ts + src/tools/) ---"
    if [[ -f "$SRC_DIR/Tool.ts" ]]; then
        t_lines=$(wc -l < "$SRC_DIR/Tool.ts" | tr -d ' ')
        echo "  Tool.ts: ${t_lines} lines"
        echo "  [SPAN:tool.execute] Tool.call() execution"
        echo "  [SPAN:tool.permission] Permission check for tool use"
    fi
    tool_count=$(find "$SRC_DIR/tools" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    echo "  Tools: ${tool_count} tool directories"
    echo ""

    # Stage 5: Cost tracking (existing observability)
    echo "--- Stage 5: Cost Tracking (src/cost-tracker.ts) ---"
    if [[ -f "$SRC_DIR/cost-tracker.ts" ]]; then
        ct_lines=$(wc -l < "$SRC_DIR/cost-tracker.ts" | tr -d ' ')
        echo "  File: ${ct_lines} lines"
        echo "  [METRIC:cost.tokens] Token counts per model"
        echo "  [METRIC:cost.usd] USD cost tracking"
        echo "  [METRIC:cost.duration] API call duration"
        echo "  Existing metrics to integrate:"
        grep -nE "export\s+(function|const)" "$SRC_DIR/cost-tracker.ts" 2>/dev/null | head -10 | sed 's/^/    /'
    fi
    echo ""

    # Stage 6: State changes
    echo "--- Stage 6: State Management (src/state/) ---"
    state_files=$(find "$SRC_DIR/state" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
    echo "  Files: ${state_files}"
    echo "  [SPAN:state.mutation] AppState changes"
    echo "  Key state: AppState type, AppStateStore, selectors"
    echo ""

    # Span correlation strategy
    echo "=== Span Correlation Strategy ==="
    echo ""
    echo "Each trace gets a correlation ID (sessionId + queryId):"
    echo "  traceId = sessionId (from src/bootstrap/state.js)"
    echo "  spanId  = random UUID per span"
    echo "  parentSpanId = linking spans in the pipeline"
    echo ""
    echo "Span nesting:"
    echo "  [repl.input] (root span)"
    echo "    [query.engine] (child of repl.input)"
    echo "      [query.api_call] (child of query.engine)"
    echo "        [query.stream] (child of query.api_call)"
    echo "      [tool.execute] (child of query.engine)"
    echo "        [tool.permission] (child of tool.execute)"
    echo "      [state.mutation] (child of query.engine)"
    echo ""

    # Existing tracing infrastructure
    echo "=== Existing Tracing Infrastructure ==="
    echo ""
    echo "  1. Startup profiler: src/utils/startupProfiler.ts"
    echo "     - profileCheckpoint() API already exists"
    echo "     - Uses perf_hooks for standard timing"
    echo ""
    echo "  2. Debug logging: src/utils/debug.ts"
    echo "     - logForDebugging() with filtered levels"
    echo "     - CLAUDE_CODE_DEBUG_LOG_LEVEL env var"
    echo ""
    echo "  3. Profiler base: src/utils/profilerBase.ts"
    echo "     - Shared timeline format"
    echo "     - formatMs(), formatTimelineLine()"
    echo ""
    echo "  Recommendation: Extend profilerBase with span-based tracing"
    echo "  rather than creating a parallel system."

} > "$PLAN_FILE"

echo "Phase 2: Generating trace template..."

cat > "$TEMPLATE_FILE" << 'TEMPLATE'
// Pipeline Trace Instrumentation Template
// Add this to src/services/observability/pipelineTrace.ts
// Extends the existing profilerBase infrastructure.

import { performance } from 'perf_hooks';
import { logForDebugging } from '../utils/debug.js';

export interface TraceSpan {
  traceId: string;
  spanId: string;
  parentSpanId: string | null;
  name: string;
  startTime: number;
  endTime?: number;
  status: 'ok' | 'error' | 'timeout';
  attributes: Record<string, string | number | boolean>;
  events: Array<{ name: string; timestamp: number; attributes?: Record<string, unknown> }>;
}

export class PipelineTracer {
  private spans: Map<string, TraceSpan> = new Map();
  private enabled: boolean;

  constructor() {
    // Enable via CLAUDE_PIPELINE_TRACE=1
    this.enabled = process.env.CLAUDE_PIPELINE_TRACE === '1';
  }

  isEnabled(): boolean { return this.enabled; }

  startSpan(
    traceId: string,
    name: string,
    parentSpanId: string | null = null,
    attributes: Record<string, string | number | boolean> = {}
  ): string {
    if (!this.enabled) return '';

    const spanId = crypto.randomUUID();
    const span: TraceSpan = {
      traceId,
      spanId,
      parentSpanId,
      name,
      startTime: performance.now(),
      status: 'ok',
      attributes,
      events: [],
    };

    this.spans.set(spanId, span);
    logForDebugging(`[trace] START ${name} span=${spanId} trace=${traceId}`);
    return spanId;
  }

  endSpan(spanId: string, status: 'ok' | 'error' | 'timeout' = 'ok'): void {
    if (!this.enabled || !spanId) return;

    const span = this.spans.get(spanId);
    if (!span) return;

    span.endTime = performance.now();
    span.status = status;
    const duration = span.endTime - span.startTime;

    logForDebugging(
      `[trace] END ${span.name} span=${spanId} status=${status} duration=${duration.toFixed(1)}ms`
    );
  }

  addEvent(spanId: string, name: string, attributes?: Record<string, unknown>): void {
    if (!this.enabled || !spanId) return;

    const span = this.spans.get(spanId);
    if (!span) return;

    span.events.push({
      name,
      timestamp: performance.now(),
      attributes,
    });
  }

  setAttribute(spanId: string, key: string, value: string | number | boolean): void {
    if (!this.enabled || !spanId) return;

    const span = this.spans.get(spanId);
    if (!span) return;

    span.attributes[key] = value;
  }

  getTrace(traceId: string): TraceSpan[] {
    const traceSpans: TraceSpan[] = [];
    for (const span of this.spans.values()) {
      if (span.traceId === traceId) {
        traceSpans.push(span);
      }
    }
    return traceSpans.sort((a, b) => a.startTime - b.startTime);
  }

  renderTrace(traceId: string): string {
    const spans = this.getTrace(traceId);
    if (spans.length === 0) return 'No spans found for trace';

    const lines: string[] = [`Trace: ${traceId}`, ''];

    for (const span of spans) {
      const duration = span.endTime ? span.endTime - span.startTime : 0;
      const indent = span.parentSpanId ? '  ' : '';
      const statusIcon = span.status === 'ok' ? '[OK]' : span.status === 'error' ? '[ERR]' : '[TMO]';
      lines.push(
        `${indent}${statusIcon} ${span.name} (${duration.toFixed(1)}ms) span=${span.spanId.slice(0, 8)}`
      );

      for (const [k, v] of Object.entries(span.attributes)) {
        lines.push(`${indent}  ${k}: ${v}`);
      }
    }

    const totalDuration = spans.length > 0
      ? (spans[spans.length - 1].endTime || performance.now()) - spans[0].startTime
      : 0;
    lines.push('', `Total: ${totalDuration.toFixed(1)}ms across ${spans.length} spans`);

    return lines.join('\n');
  }

  clear(): void {
    this.spans.clear();
  }
}

// Singleton
export const pipelineTracer = new PipelineTracer();
TEMPLATE

echo "Phase 3: Analysis complete."
echo ""
echo "Artifacts:"
echo "  Plan: ${PLAN_FILE}"
echo "  Template: ${TEMPLATE_FILE}"
echo ""
cat "$PLAN_FILE"

echo ""
echo "PASSED: Pipeline trace analysis complete"
exit 0
