#!/bin/bash
# scaffold/collect-metrics.sh
# Collects all available metrics from the codebase and generates a report.
# This script scans for existing metric collection points, identifies what
# metrics are already tracked vs. what is missing, and produces a unified
# metrics catalog.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
SRC_DIR="${PROJECT_ROOT}/src"
OUTPUT_DIR="${PROJECT_ROOT}/.scaffolding/observability"

mkdir -p "$OUTPUT_DIR"

echo "=== Metrics Collection Analyzer ==="
echo ""

CATALOG_FILE="${OUTPUT_DIR}/metrics-catalog.txt"
REPORT_FILE="${OUTPUT_DIR}/metrics-report.txt"

{
    echo "Open-ClaudeCode Metrics Catalog"
    echo "================================"
    echo "Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo ""

    # Category 1: Cost/Usage metrics (from cost-tracker and bootstrap/state)
    echo "## CATEGORY: Cost & Usage"
    echo ""
    echo "Source: src/cost-tracker.ts, src/bootstrap/state.ts"
    echo ""

    if [[ -f "$SRC_DIR/cost-tracker.ts" ]]; then
        echo "  Existing metrics:"
        grep -oE "get\w+Cost\w*|get\w+Token\w*|get\w+Duration\w*|get\w+Usage\w*" "$SRC_DIR/cost-tracker.ts" 2>/dev/null | sort -u | while read -r metric; do
            echo "    [COST] ${metric}"
        done
        echo ""
    fi

    if [[ -f "$SRC_DIR/bootstrap/state.ts" ]]; then
        echo "  State-backed counters:"
        grep -oE "get\w+Counter\w*|Total\w+Token\w*|Total\w+Cost\w*|Total\w+Duration\w*" "$SRC_DIR/bootstrap/state.ts" 2>/dev/null | sort -u | while read -r metric; do
            echo "    [STATE] ${metric}"
        done
        echo ""
    fi

    # Category 2: Performance metrics
    echo "## CATEGORY: Performance"
    echo ""
    echo "Source: src/utils/startupProfiler.ts, src/utils/profilerBase.ts"
    echo ""

    if [[ -f "$SRC_DIR/utils/startupProfiler.ts" ]]; then
        echo "  Startup profiling phases:"
        grep -oE "\w+:\s*\['\w+',\s*'\w+'\]" "$SRC_DIR/utils/startupProfiler.ts" 2>/dev/null | while read -r phase; do
            echo "    [PERF] ${phase}"
        done
        echo "  Control: CLAUDE_CODE_PROFILE_STARTUP=1"
        echo ""
    fi

    # Category 3: Tool metrics
    echo "## CATEGORY: Tool Execution"
    echo ""
    echo "Source: src/tools/*/"
    echo ""
    echo "  [TOOL] tool.count — Number of tool calls per session"
    echo "  [TOOL] tool.duration — Per-tool execution time (MISSING: currently only total)"
    echo "  [TOOL] tool.success_rate — Tool call success/failure ratio (MISSING)"
    echo "  [TOOL] tool.permission_denied — Permission denial count (partial: denialTracking.ts)"
    echo ""

    # Category 4: Query/API metrics
    echo "## CATEGORY: Query & API"
    echo ""
    echo "Source: src/QueryEngine.ts, src/query.ts, src/services/api/"
    echo ""
    echo "  [API] api.latency — API call round-trip time (exists: getTotalAPIDuration)"
    echo "  [API] api.retry_count — Retry attempts (partial: categorizeRetryableAPIError)"
    echo "  [API] api.stream_duration — Streaming response time (MISSING: separate metric)"
    echo "  [API] api.context_window_usage — Context window fill rate (MISSING: available from model config)"
    echo ""

    # Category 5: State metrics
    echo "## CATEGORY: Application State"
    echo ""
    echo "Source: src/state/"
    echo ""
    echo "  [STATE] state.message_count — Messages in conversation (computable)"
    echo "  [STATE] state.tool_use_count — Active tool uses (computable from speculation)"
    echo "  [STATE] state.mutation_rate — State changes per minute (MISSING)"
    echo "  [STATE] state.memory_estimate — Approximate state size (MISSING)"
    echo ""

    # Category 6: Session metrics
    echo "## CATEGORY: Session"
    echo ""
    echo "Source: src/bootstrap/state.ts"
    echo ""
    echo "  [SESSION] session.id — Session identifier (exists: getSessionId)"
    echo "  [SESSION] session.duration — Total session wall time (exists: getTotalDuration)"
    echo "  [SESSION] session.turn_count — Number of user turns (MISSING)"
    echo "  [SESSION] session.files_modified — Number of files changed (partial: fileHistory)"
    echo ""

    # Category 7: Analytics events
    echo "## CATEGORY: Analytics Events"
    echo ""
    echo "Source: src/services/analytics/"
    echo ""
    if [[ -d "$SRC_DIR/services/analytics" ]]; then
        echo "  Analytics service files:"
        find "$SRC_DIR/services/analytics" -name "*.ts" 2>/dev/null | while read -r f; do
            relpath="${f#"$SRC_DIR/"}"
            echo "    ${relpath}"
        done
    fi
    echo ""

    # Gaps analysis
    echo "========================================="
    echo "## GAPS ANALYSIS"
    echo "========================================="
    echo ""
    echo "Missing metrics (HIGH priority):"
    echo "  1. Per-tool latency histogram — only total tool duration exists"
    echo "  2. Context window utilization — model config available but not tracked"
    echo "  3. Session turn count — easy to compute, not currently tracked"
    echo "  4. State mutation rate — no audit of state changes over time"
    echo "  5. Error rate by category — errors typed but not aggregated"
    echo ""
    echo "Missing metrics (MEDIUM priority):"
    echo "  6. Tool call success/failure ratio"
    echo "  7. Permission denial rate"
    echo "  8. Cache hit rate (input vs. cache read tokens)"
    echo "  9. File operation counts (reads, writes, edits per session)"
    echo "  10. Memory usage over time"
    echo ""

} > "$CATALOG_FILE"

# Generate collection template
COLLECTION_TEMPLATE="${OUTPUT_DIR}/metrics-collection-template.ts"
cat > "$COLLECTION_TEMPLATE" << 'TEMPLATE'
// Unified Metrics Collection Template
// Add this to src/services/observability/metricsCollector.ts
// Consolidates all existing metrics into a single collection point.

import { getTotalCostUSD, getTotalDuration, getTotalAPIDuration } from '../cost-tracker.js';
import { getTotalInputTokens, getTotalOutputTokens } from '../bootstrap/state.js';

export interface MetricSnapshot {
  timestamp: number;
  sessionId: string;

  // Cost
  totalCostUSD: number;
  totalDuration: number;
  totalApiDuration: number;

  // Tokens
  totalInputTokens: number;
  totalOutputTokens: number;

  // Session
  messageCount: number;
  toolUseCount: number;
  turnCount: number;

  // Memory
  heapUsed: number;
  heapTotal: number;
  rss: number;
}

class MetricsCollector {
  private snapshots: MetricSnapshot[] = [];
  private interval: ReturnType<typeof setInterval> | null = null;
  private enabled = false;

  start(sessionId: string, intervalMs: number = 30000): void {
    if (this.enabled) return;
    this.enabled = true;

    this.interval = setInterval(() => {
      this.collect(sessionId);
    }, intervalMs);
  }

  stop(): MetricSnapshot[] {
    if (this.interval) {
      clearInterval(this.interval);
      this.interval = null;
    }
    this.enabled = false;
    return [...this.snapshots];
  }

  collect(sessionId: string): MetricSnapshot {
    const mem = process.memoryUsage();

    const snapshot: MetricSnapshot = {
      timestamp: Date.now(),
      sessionId,
      totalCostUSD: getTotalCostUSD(),
      totalDuration: getTotalDuration(),
      totalApiDuration: getTotalAPIDuration(),
      totalInputTokens: getTotalInputTokens(),
      totalOutputTokens: getTotalOutputTokens(),
      messageCount: 0,    // TODO: read from AppState
      toolUseCount: 0,    // TODO: read from AppState
      turnCount: 0,       // TODO: track separately
      heapUsed: mem.heapUsed,
      heapTotal: mem.heapTotal,
      rss: mem.rss,
    };

    this.snapshots.push(snapshot);
    return snapshot;
  }

  renderTimeline(): string {
    if (this.snapshots.length === 0) return 'No metrics collected';

    const lines: string[] = ['Metrics Timeline:', ''];

    for (const s of this.snapshots) {
      const time = new Date(s.timestamp).toISOString().slice(11, 19);
      lines.push(
        `${time} cost=$${s.totalCostUSD.toFixed(4)} ` +
        `tokens=${s.totalInputTokens + s.totalOutputTokens} ` +
        `heap=${(s.heapUsed / 1024 / 1024).toFixed(1)}MB ` +
        `dur=${(s.totalDuration / 1000).toFixed(1)}s`
      );
    }

    return lines.join('\n');
  }
}

export const metricsCollector = new MetricsCollector();
TEMPLATE

# Copy catalog to report
cp "$CATALOG_FILE" "$REPORT_FILE"

echo "Artifacts:"
echo "  Catalog: ${CATALOG_FILE}"
echo "  Report: ${REPORT_FILE}"
echo "  Template: ${COLLECTION_TEMPLATE}"
echo ""
echo "PASSED: Metrics collection analysis complete"
exit 0
