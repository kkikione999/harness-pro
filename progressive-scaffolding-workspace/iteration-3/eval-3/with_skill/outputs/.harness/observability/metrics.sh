#!/bin/bash
# metrics.sh — Metrics endpoint query for Open-ClaudeCode
#
# This script queries and reports on the project's metrics infrastructure:
#   - OTEL metrics (configured via OTEL_METRICS_EXPORTER)
#   - BigQuery metrics pipeline
#   - Prometheus exporter (if enabled)
#   - Datadog custom metrics
#   - Derived Perfetto metrics (ITPS, OTPS, cache hit rate)
#
# Observability dimensions addressed:
#   O1 (Feedback) — reads structured metric output
#   O2 (Persist)   — queries persisted metric data
#   O3 (Queryable) — supports structured metric queries
#
# Usage:
#   ./metrics.sh summary          — overall metrics infrastructure summary
#   ./metrics.sh counters         — show all metric counters defined in source
#   ./metrics.sh histograms       — show all histogram metrics in source
#   ./metrics.sh gauges           — show all gauge/up-down counter metrics
#   ./metrics.sh datadog          — show Datadog integration status
#   ./metrics.sh bigquery         — show BigQuery pipeline status
#   ./metrics.sh perfetto <file>  — extract derived metrics from a Perfetto trace
#   ./metrics.sh env              — show environment variable controls for metrics

set -euo pipefail

PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
CLAUDE_HOME="${CLAUDE_CONFIG_HOME:-$HOME/.claude}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

has_jq() {
    command -v jq &>/dev/null
}

# --- Command: summary ---
cmd_summary() {
    echo -e "${CYAN}=== Metrics Infrastructure Summary ===${NC}"
    echo ""

    echo -e "${BLUE}Metric Providers:${NC}"
    echo ""

    echo "  1. OpenTelemetry SDK (src/utils/telemetry/instrumentation.ts)"
    echo "     - MeterProvider with PeriodicExportingMetricReader"
    echo "     - Export interval: 60s (OTEL_METRIC_EXPORT_INTERVAL)"
    echo "     - Temporality: DELTA (required for BQ aggregation)"
    echo "     - Exporters: console, otlp (grpc/http-json/http-protobuf), prometheus"
    echo ""

    echo "  2. BigQuery Metrics Exporter (src/utils/telemetry/bigqueryExporter.ts)"
    echo "     - Endpoint: https://api.anthropic.com/api/claude_code/metrics"
    echo "     - Export interval: 300s (5 min)"
    echo "     - Enabled for: API customers, C4E, Teams"
    echo "     - Auth: Uses getAuthHeaders() with apiKeyHelper"
    echo ""

    echo "  3. Datadog Metrics (via log pipeline, src/services/analytics/datadog.ts)"
    echo "     - Endpoint: https://http-intake.logs.us5.datadoghq.com/api/v2/logs"
    echo "     - Flush interval: 15s (CLAUDE_CODE_DATADOG_FLUSH_INTERVAL_MS)"
    echo "     - Max batch: 100 logs"
    echo "     - Network timeout: 5s"
    echo ""

    echo "  4. Perfetto Derived Metrics (src/utils/telemetry/perfettoTracing.ts)"
    echo "     - ITPS: Input tokens per second (prompt processing speed)"
    echo "     - OTPS: Output tokens per second (sampling speed)"
    echo "     - Cache hit rate: Percentage of prompt tokens from cache"
    echo "     - TTFT: Time to first token"
    echo "     - TTLT: Time to last token"
    echo ""

    echo -e "${BLUE}Resource Attributes (on all metrics):${NC}"
    echo "  service.name:   claude-code"
    echo "  service.version: <MACRO.VERSION>"
    echo "  os.type:        <detected>"
    echo "  os.version:     <detected>"
    echo "  host.arch:      <detected>"
    echo "  user.id:        <hash-based>"
    echo "  session.id:     <uuid> (controlled by OTEL_METRICS_INCLUDE_SESSION_ID)"
    echo "  user.account_id: <tagged-id> (controlled by OTEL_METRICS_INCLUDE_ACCOUNT_UUID)"
    echo ""

    echo -e "${BLUE}Privacy Controls:${NC}"
    echo "  - Organization-level opt-out via checkMetricsEnabled()"
    echo "  - Trust dialog must be accepted in interactive mode"
    echo "  - 3P providers (Bedrock/Vertex/Foundry) excluded from Datadog"
    echo "  - Model names normalized for cardinality (external users)"
    echo "  - MCP tool names redacted to 'mcp'"
    echo "  - Dev versions truncated (remove timestamp/sha)"
    echo "  - User bucketing: 30 buckets via SHA256 hash"
}

# --- Command: counters ---
cmd_counters() {
    echo -e "${CYAN}=== Metric Counters ===${NC}"
    echo ""

    echo -e "${BLUE}Counter definitions in source code:${NC}"
    grep -rn "createCounter\|\.add(\|counter\|Counter" \
        "$PROJECT_ROOT/src/" --include="*.ts" 2>/dev/null | \
        grep -v "node_modules" | \
        grep -v "\.d\.ts" | \
        grep -v "test" | \
        head -30 | while IFS= read -r line; do
            local file
            file=$(echo "$line" | cut -d: -f1 | sed "s|$PROJECT_ROOT/||")
            local lineno
            lineno=$(echo "$line" | cut -d: -f2)
            local content
            content=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//')
            echo "  $file:$lineno"
            echo "    $content"
        done
    echo ""

    echo -e "${BLUE}Meter usage (getMeter calls):${NC}"
    grep -rn "getMeter\|\.createCounter\|\.createHistogram\|\.createUpDownCounter\|\.createGauge" \
        "$PROJECT_ROOT/src/" --include="*.ts" 2>/dev/null | \
        grep -v "node_modules" | \
        grep -v "\.d\.ts" | \
        head -20 | while IFS= read -r line; do
            local file
            file=$(echo "$line" | cut -d: -f1 | sed "s|$PROJECT_ROOT/||")
            local content
            content=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//')
            echo "  $file: $content"
        done
}

# --- Command: histograms ---
cmd_histograms() {
    echo -e "${CYAN}=== Histogram Metrics ===${NC}"
    echo ""

    echo -e "${BLUE}Histogram definitions:${NC}"
    grep -rn "createHistogram\|\.record(" \
        "$PROJECT_ROOT/src/" --include="*.ts" 2>/dev/null | \
        grep -v "node_modules" | \
        grep -v "\.d\.ts" | \
        grep -v "test" | \
        head -20 | while IFS= read -r line; do
            local file
            file=$(echo "$line" | cut -d: -f1 | sed "s|$PROJECT_ROOT/||")
            local content
            content=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//')
            echo "  $file: $content"
        done
    echo ""

    echo -e "${BLUE}Duration tracking in spans:${NC}"
    grep -rn "duration_ms\|duration_us\|ttft_ms\|ttlt_ms" \
        "$PROJECT_ROOT/src/utils/telemetry/" --include="*.ts" 2>/dev/null | \
        sed 's/^/  /'
}

# --- Command: gauges ---
cmd_gauges() {
    echo -e "${CYAN}=== Gauge / UpDownCounter Metrics ===${NC}"
    echo ""

    echo -e "${BLUE}Gauge/UpDownCounter definitions:${NC}"
    grep -rn "createGauge\|createUpDownCounter\|createObservableGauge\|\.add\(.*-1\|\.subtract" \
        "$PROJECT_ROOT/src/" --include="*.ts" 2>/dev/null | \
        grep -v "node_modules" | \
        grep -v "\.d\.ts" | \
        head -10 | while IFS= read -r line; do
            local file
            file=$(echo "$line" | cut -d: -f1 | sed "s|$PROJECT_ROOT/||")
            local content
            content=$(echo "$line" | cut -d: -f3- | sed 's/^[[:space:]]*//')
            echo "  $file: $content"
        done

    echo ""
    echo -e "${BLUE}Perfetto counter events (emitPerfettoCounter):${NC}"
    grep -rn "emitPerfettoCounter\|'C'" \
        "$PROJECT_ROOT/src/utils/telemetry/perfettoTracing.ts" 2>/dev/null | \
        sed 's/^/  /'
}

# --- Command: datadog ---
cmd_datadog() {
    echo -e "${CYAN}=== Datadog Integration ===${NC}"
    echo ""

    echo -e "${BLUE}Configuration:${NC}"
    echo "  Endpoint: https://http-intake.logs.us5.datadoghq.com/api/v2/logs"
    echo "  Client token: pubbbf48e6d78dae54bceaa4acf463299bf"
    echo "  Service: claude-code"
    echo "  Hostname: claude-code"
    echo "  Flush: 15s (CLAUDE_CODE_DATADOG_FLUSH_INTERVAL_MS)"
    echo "  Batch size: 100 max"
    echo "  Timeout: 5s"
    echo ""

    echo -e "${BLUE}Allowed events ($(grep -c "'tengu_" "$PROJECT_ROOT/src/services/analytics/datadog.ts" 2>/dev/null || echo "0")):${NC}"
    grep -oE "'tengu_[^']+'" "$PROJECT_ROOT/src/services/analytics/datadog.ts" 2>/dev/null | \
        sed "s/'//g" | sort -u | while read -r evt; do
            echo "  $evt"
        done
    echo ""

    echo -e "${BLUE}Tag fields (high-cardinality for filtering):${NC}"
    grep -A 20 "const TAG_FIELDS" "$PROJECT_ROOT/src/services/analytics/datadog.ts" 2>/dev/null | \
        grep -oE "'[^']+'" | sed "s/'//g" | while read -r tag; do
            echo "  $tag"
        done
    echo ""

    echo -e "${BLUE}Cardinality controls:${NC}"
    echo "  - Model names: normalized to canonical names (external users)"
    echo "  - MCP tools: redacted to 'mcp'"
    echo "  - Dev versions: truncated to base+date"
    echo "  - User bucketing: 30 buckets via SHA256"
    echo "  - HTTP status: converted to range (1xx-5xx)"
    echo "  - Gate: tengu_log_datadog_events (GrowthBook)"
}

# --- Command: bigquery ---
cmd_bigquery() {
    echo -e "${CYAN}=== BigQuery Metrics Pipeline ===${NC}"
    echo ""

    echo -e "${BLUE}Exporter (src/utils/telemetry/bigqueryExporter.ts):${NC}"
    echo "  Class: BigQueryMetricsExporter (implements PushMetricExporter)"
    echo "  Endpoint: https://api.anthropic.com/api/claude_code/metrics"
    echo "  Timeout: 5s"
    echo "  Export interval: 300s (5 min, separate PeriodicExportingMetricReader)"
    echo "  Temporality: DELTA"
    echo ""

    echo -e "${BLUE}Payload structure:${NC}"
    echo "  resource_attributes:"
    echo "    service.name, service.version, os.type, os.version, host.arch"
    echo "    user.customer_type (claude_ai | api)"
    echo "    user.subscription_type (enterprise, team, etc.)"
    echo "    wsl.version (conditional)"
    echo "  metrics[]:"
    echo "    name, description, unit, data_points[]"
    echo "  data_points[]:"
    echo "    attributes: {key: string}, value: number, timestamp: ISO string"
    echo ""

    echo -e "${BLUE}Eligibility:${NC}"
    echo "  - 1P API customers (is1PApiCustomer())"
    echo "  - Claude for Enterprise users"
    echo "  - Claude for Teams users"
    echo "  - NOT: Bedrock/Vertex/Foundry"
    echo ""

    echo -e "${BLUE}Trust requirements:${NC}"
    echo "  - Interactive: trust dialog must be accepted (checkHasTrustDialogAccepted)"
    echo "  - Non-interactive: always allowed"
    echo "  - Organization opt-out: checkMetricsEnabled() via API"
}

# --- Command: perfetto ---
cmd_perfetto() {
    local trace_file="${1:-}"
    if [ -z "$trace_file" ]; then
        echo -e "${YELLOW}Usage: ./metrics.sh perfetto <trace-file-or-session-id>${NC}"
        echo ""
        echo "Extracts derived metrics from a Perfetto trace file."
        echo ""
        echo "Available traces:"
        local traces_dir="${CLAUDE_CONFIG_HOME:-$HOME/.claude}/traces"
        if [ -d "$traces_dir" ]; then
            find "$traces_dir" -name "trace-*.json" -type f 2>/dev/null | while read -r f; do
                echo "  $(basename "$f")"
            done
        else
            echo "  (none found)"
        fi
        return
    fi

    if [ ! -f "$trace_file" ]; then
        trace_file="${CLAUDE_CONFIG_HOME:-$HOME/.claude}/traces/trace-${trace_file}.json"
    fi

    if [ ! -f "$trace_file" ]; then
        echo -e "${RED}File not found: $trace_file${NC}"
        return 1
    fi

    echo -e "${CYAN}=== Perfetto Derived Metrics: $(basename "$trace_file") ===${NC}"
    echo ""

    if ! has_jq; then
        echo -e "${YELLOW}jq required for metric extraction. Install with: brew install jq${NC}"
        return
    fi

    echo -e "${BLUE}API Call Performance:${NC}"
    jq -r '.traceEvents[] | select(.name == "API Call") | select(.ph == "E") |
        "  model=\(.args.model // "unknown") " +
        "ttft=\(.args.ttft_ms // "?")ms " +
        "ttlt=\(.args.ttlt_ms // "?")ms " +
        "itps=\(.args.itps // "?") " +
        "otps=\(.args.otps // "?") " +
        "cache_hit=\(.args.cache_hit_rate_pct // "?")% " +
        "success=\(.args.success // "?")"' \
        "$trace_file" 2>/dev/null | head -20
    echo ""

    echo -e "${BLUE}Token Usage:${NC}"
    jq -r '.traceEvents[] | select(.name == "API Call") | select(.ph == "E") |
        "  model=\(.args.model // "unknown") " +
        "prompt=\(.args.prompt_tokens // 0) " +
        "output=\(.args.output_tokens // 0) " +
        "cache_read=\(.args.cache_read_tokens // 0) " +
        "cache_create=\(.args.cache_creation_tokens // 0)"' \
        "$trace_file" 2>/dev/null | head -20
    echo ""

    echo -e "${BLUE}Tool Execution Times:${NC}"
    jq -r '.traceEvents[] | select(.cat == "tool") | select(.ph == "E") |
        "  \(.name) dur=\(.args.duration_ms // "?")ms success=\(.args.success // "?")"' \
        "$trace_file" 2>/dev/null | head -20
    echo ""

    echo -e "${BLUE}Interaction Latency:${NC}"
    jq -r '.traceEvents[] | select(.name == "Interaction") | select(.ph == "E") |
        "  duration=\(.args.duration_ms // "?")ms prompt_len=\(.args.user_prompt_length // "?")"' \
        "$trace_file" 2>/dev/null | head -20

    echo ""
    echo -e "${BLUE}Aggregated Summary:${NC}"
    local total_api_calls
    total_api_calls=$(jq '[.traceEvents[] | select(.name == "API Call") | select(.ph == "E")] | length' "$trace_file" 2>/dev/null || echo "?")
    local total_tools
    total_tools=$(jq '[.traceEvents[] | select(.cat == "tool") | select(.ph == "E")] | length' "$trace_file" 2>/dev/null || echo "?")
    local total_interactions
    total_interactions=$(jq '[.traceEvents[] | select(.name == "Interaction") | select(.ph == "E")] | length' "$trace_file" 2>/dev/null || echo "?")
    local avg_ttft
    avg_ttft=$(jq -r '[.traceEvents[] | select(.name == "API Call") | select(.ph == "E") | .args.ttft_ms] | add / length // "?"' "$trace_file" 2>/dev/null || echo "?")
    echo "  API calls: $total_api_calls"
    echo "  Tool calls: $total_tools"
    echo "  Interactions: $total_interactions"
    echo "  Avg TTFT: ${avg_ttft}ms"
}

# --- Command: env ---
cmd_env() {
    echo -e "${CYAN}=== Metrics Environment Variables ===${NC}"
    echo ""

    echo -e "${BLUE}Enable/Disable:${NC}"
    echo "  CLAUDE_CODE_ENABLE_TELEMETRY        Enable OTEL metrics+logs+traces"
    echo "  CLAUDE_CODE_USE_BEDROCK             Disable analytics (Bedrock users)"
    echo "  CLAUDE_CODE_USE_VERTEX              Disable analytics (Vertex users)"
    echo "  CLAUDE_CODE_USE_FOUNDRY             Disable analytics (Foundry users)"
    echo ""

    echo -e "${BLUE}Export Configuration:${NC}"
    echo "  OTEL_METRICS_EXPORTER               console | otlp | prometheus"
    echo "  OTEL_EXPORTER_OTLP_PROTOCOL         grpc | http/json | http/protobuf"
    echo "  OTEL_EXPORTER_OTLP_ENDPOINT         Collector endpoint URL"
    echo "  OTEL_EXPORTER_OTLP_HEADERS          Key=value auth headers"
    echo "  OTEL_METRIC_EXPORT_INTERVAL         Export interval in ms (default: 60000)"
    echo "  OTEL_EXPORTER_OTLP_METRICS_PROTOCOL Per-signal protocol override"
    echo "  OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE  delta | cumulative (default: delta)"
    echo ""

    echo -e "${BLUE}Cardinality Controls:${NC}"
    echo "  OTEL_METRICS_INCLUDE_SESSION_ID     Include session.id attribute (default: true)"
    echo "  OTEL_METRICS_INCLUDE_VERSION        Include app.version attribute (default: false)"
    echo "  OTEL_METRICS_INCLUDE_ACCOUNT_UUID   Include user.account_uuid (default: true)"
    echo ""

    echo -e "${BLUE}Shutdown:${NC}"
    echo "  CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS  Shutdown flush timeout (default: 2000)"
    echo "  CLAUDE_CODE_OTEL_FLUSH_TIMEOUT_MS     Explicit flush timeout (default: 5000)"
    echo ""

    echo -e "${BLUE}Datadog:${NC}"
    echo "  CLAUDE_CODE_DATADOG_FLUSH_INTERVAL_MS  Flush interval in ms (default: 15000)"
    echo ""

    echo -e "${BLUE}Perfetto:${NC}"
    echo "  CLAUDE_CODE_PERFETTO_TRACE             Enable (1) or set custom path"
    echo "  CLAUDE_CODE_PERFETTO_WRITE_INTERVAL_S  Periodic write interval in seconds"
    echo ""

    echo -e "${BLUE}Beta Tracing:${NC}"
    echo "  CLAUDE_CODE_ENHANCED_TELEMETRY_BETA    Enable session tracing"
    echo "  ENABLE_BETA_TRACING_DETAILED           Enable detailed beta tracing"
    echo "  BETA_TRACING_ENDPOINT                  Beta trace collector URL"
    echo ""

    echo -e "${BLUE}Log Content Controls:${NC}"
    echo "  OTEL_LOG_USER_PROMPTS                 Log user prompt content (default: redacted)"
    echo "  OTEL_LOG_TOOL_CONTENT                 Log tool input/output content"
    echo ""

    echo -e "${BLUE}Proxy/mTLS:${NC}"
    echo "  HTTPS_PROXY / https_proxy             Proxy for OTLP exporter"
    echo "  NODE_EXTRA_CA_CERTS                   Custom CA certificates"
    echo "  CLAUDE_CODE_MTLS_CERT                 mTLS client certificate"
    echo "  CLAUDE_CODE_MTLS_KEY                  mTLS client key"
    echo "  CLAUDE_CODE_MTLS_PASSPHRASE           mTLS key passphrase"
}

# --- Main ---
COMMAND="${1:-summary}"
shift || true

case "$COMMAND" in
    summary)
        cmd_summary
        ;;
    counters)
        cmd_counters
        ;;
    histograms)
        cmd_histograms
        ;;
    gauges)
        cmd_gauges
        ;;
    datadog)
        cmd_datadog
        ;;
    bigquery)
        cmd_bigquery
        ;;
    perfetto)
        cmd_perfetto "${1:-}"
        ;;
    env)
        cmd_env
        ;;
    *)
        echo "Open-ClaudeCode Metrics Query"
        echo ""
        echo "Usage: ./metrics.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  summary           Overall metrics infrastructure summary"
        echo "  counters          Show metric counter definitions"
        echo "  histograms        Show histogram metric definitions"
        echo "  gauges            Show gauge/up-down counter definitions"
        echo "  datadog           Datadog integration status"
        echo "  bigquery          BigQuery pipeline status"
        echo "  perfetto <file>   Extract metrics from Perfetto trace"
        echo "  env               Environment variable controls"
        ;;
esac
