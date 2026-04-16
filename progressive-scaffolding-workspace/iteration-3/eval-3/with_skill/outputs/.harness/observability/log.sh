#!/bin/bash
# log.sh — Structured log query for Open-ClaudeCode
#
# This script provides query access to the project's log infrastructure:
#   - Perfetto traces at ~/.claude/traces/
#   - Datadog-batched event logs
#   - OTEL debug logs (when CLAUDE_CODE_ENABLE_TELEMETRY=1)
#   - 1P event logging batch spill files
#   - Session debug output
#
# Observability dimensions addressed:
#   O1 (Feedback) — reads structured log output
#   O2 (Persist)   — queries persisted log files
#   O3 (Queryable) — supports grep/jq filtering
#
# Usage:
#   ./log.sh recent            — show last 20 log entries
#   ./log.sh errors            — filter for error-level entries
#   ./log.sh telemetry         — show OTEL telemetry debug output
#   ./log.sh traces            — list Perfetto trace files
#   ./log.sh trace <file>      — summarize a specific Perfetto trace
#   ./log.sh events            — show analytics event names from source
#   ./log.sh session <id>      — query logs for a specific session ID
#   ./log.sh grep <pattern>    — search logs for a pattern
#   ./log.sh summary           — overall log health summary

set -euo pipefail

PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
CLAUDE_HOME="${CLAUDE_CONFIG_HOME:-$HOME/.claude}"
TRACES_DIR="$CLAUDE_HOME/traces"

# Colors for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# JSON helper — use jq if available, otherwise raw output
has_jq() {
    command -v jq &>/dev/null
}

# --- Command: recent ---
cmd_recent() {
    echo -e "${CYAN}=== Recent Log Activity ===${NC}"
    echo ""

    # Check Perfetto traces
    if [ -d "$TRACES_DIR" ]; then
        local trace_count
        trace_count=$(find "$TRACES_DIR" -name "trace-*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
        echo -e "${BLUE}Perfetto traces:${NC} $trace_count files in $TRACES_DIR"
        find "$TRACES_DIR" -name "trace-*.json" -type f -exec ls -lht {} \; 2>/dev/null | head -5
        echo ""
    else
        echo -e "${YELLOW}No Perfetto traces directory found at $TRACES_DIR${NC}"
        echo "  Enable with: CLAUDE_CODE_PERFETTO_TRACE=1"
        echo ""
    fi

    # Check for OTEL debug output patterns in project source
    echo -e "${BLUE}Telemetry source files:${NC}"
    find "$PROJECT_ROOT/src/utils/telemetry" -name "*.ts" -type f 2>/dev/null | while read -r f; do
        local name
        name=$(basename "$f")
        local lines
        lines=$(grep -c "logForDebugging\|logError\|console\." "$f" 2>/dev/null || echo "0")
        echo "  $name ($lines log statements)"
    done
    echo ""

    # Check for batch spill files from 1P event logging
    local spill_count
    spill_count=$(find "$CLAUDE_HOME" -name "*.batch.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo -e "${BLUE}1P event batch spill files:${NC} $spill_count"
    if [ "$spill_count" -gt 0 ]; then
        find "$CLAUDE_HOME" -name "*.batch.json" -type f -exec ls -lht {} \; 2>/dev/null | head -5
    fi
    echo ""

    # Analytics event types registered in the codebase
    echo -e "${BLUE}Registered analytics events (last 20):${NC}"
    grep -rh "logEvent\b\|logOTelEvent\b\|logEventAsync\b" \
        "$PROJECT_ROOT/src/" \
        --include="*.ts" 2>/dev/null | \
        sed -n "s/.*log\(OTel\)\?Event(['\"]\([^'\"]*\).*/\2/p" | \
        sort -u | \
        tail -20
}

# --- Command: errors ---
cmd_errors() {
    echo -e "${RED}=== Error Log Query ===${NC}"
    echo ""

    # Search source code for error logging patterns
    echo -e "${RED}Error handling patterns in telemetry:${NC}"
    grep -rn "logError\|logForDebugging.*error\|TelemetryTimeoutError\|errorMessage(" \
        "$PROJECT_ROOT/src/utils/telemetry/" \
        --include="*.ts" 2>/dev/null | head -20
    echo ""

    echo -e "${RED}Error handling patterns in analytics:${NC}"
    grep -rn "logError\|catch.*error\|error_category" \
        "$PROJECT_ROOT/src/services/analytics/" \
        --include="*.ts" 2>/dev/null | head -20
    echo ""

    # Check for error-classified events in Datadog allow list
    echo -e "${RED}Error events in Datadog allow-list:${NC}"
    grep -E "error|failed|timeout|exception" "$PROJECT_ROOT/src/services/analytics/datadog.ts" 2>/dev/null | \
        grep -oE "'[^']+'" | sort -u | sed "s/'//g"
}

# --- Command: telemetry ---
cmd_telemetry() {
    echo -e "${CYAN}=== OTEL Telemetry Status ===${NC}"
    echo ""

    echo -e "${BLUE}Instrumentation pipeline (src/utils/telemetry/instrumentation.ts):${NC}"
    echo "  Signals configured:"
    echo "    - Metrics:  OTEL_METRICS_EXPORTER (console, otlp, prometheus)"
    echo "    - Logs:     OTEL_LOGS_EXPORTER (console, otlp)"
    echo "    - Traces:   OTEL_TRACES_EXPORTER (console, otlp)"
    echo "    - BigQuery: Automatic for API/C4E/Teams users"
    echo "    - Perfetto: CLAUDE_CODE_PERFETTO_TRACE=1 (ant-only)"
    echo ""

    echo -e "${BLUE}Export intervals:${NC}"
    grep -n "DEFAULT_.*EXPORT_INTERVAL\|DEFAULT_.*DELAY\|DEFAULT_FLUSH" \
        "$PROJECT_ROOT/src/utils/telemetry/instrumentation.ts" 2>/dev/null | \
        sed 's/^/  /'
    echo ""

    echo -e "${BLUE}Environment variable controls:${NC}"
    grep -oE "process\.env\.[A-Z_]+" \
        "$PROJECT_ROOT/src/utils/telemetry/instrumentation.ts" 2>/dev/null | \
        sed 's/process.env.//g' | sort -u | \
        while read -r var; do
            echo "  $var"
        done
    echo ""

    echo -e "${BLUE}Session tracing spans (src/utils/telemetry/sessionTracing.ts):${NC}"
    grep -E "^export function (start|end|get|execute)" \
        "$PROJECT_ROOT/src/utils/telemetry/sessionTracing.ts" 2>/dev/null | \
        sed 's/export function /  /g' | sed 's/(.*$//g'
}

# --- Command: traces ---
cmd_traces() {
    echo -e "${CYAN}=== Perfetto Traces ===${NC}"
    echo ""

    if [ ! -d "$TRACES_DIR" ]; then
        echo -e "${YELLOW}No traces directory at $TRACES_DIR${NC}"
        echo "  Enable Perfetto tracing with:"
        echo "    CLAUDE_CODE_PERFETTO_TRACE=1"
        echo "  Or specify a custom path:"
        echo "    CLAUDE_CODE_PERFETTO_TRACE=/path/to/trace.json"
        return
    fi

    local trace_files
    trace_files=$(find "$TRACES_DIR" -name "trace-*.json" -type f 2>/dev/null)
    local trace_count
    trace_count=$(echo "$trace_files" | grep -c "." || echo "0")

    if [ "$trace_count" -eq 0 ]; then
        echo -e "${YELLOW}No trace files found in $TRACES_DIR${NC}"
        return
    fi

    echo -e "${GREEN}Found $trace_count trace file(s):${NC}"
    echo ""
    echo "$trace_files" | while read -r f; do
        local size
        size=$(ls -lh "$f" | awk '{print $5}')
        local modified
        modified=$(ls -l "$f" | awk '{print $6, $7, $8}')
        local session_id
        session_id=$(basename "$f" | sed 's/trace-//g' | sed 's/\.json//g')

        echo -e "  ${BLUE}$session_id${NC}"
        echo "    File: $f"
        echo "    Size: $size  Modified: $modified"

        if has_jq; then
            local event_count
            event_count=$(jq '.traceEvents | length' "$f" 2>/dev/null || echo "?")
            local agent_count
            agent_count=$(jq '.metadata.agent_count // 0' "$f" 2>/dev/null || echo "?")
            local session_id_meta
            session_id_meta=$(jq -r '.metadata.session_id // "unknown"' "$f" 2>/dev/null || echo "?")
            echo "    Events: $event_count  Agents: $agent_count  Session: $session_id_meta"
        fi
        echo ""
    done
}

# --- Command: trace <file> ---
cmd_trace_detail() {
    local trace_file="${1:-}"
    if [ -z "$trace_file" ]; then
        echo "Usage: ./log.sh trace <trace-file>"
        return 1
    fi

    if [ ! -f "$trace_file" ]; then
        # Try as a session ID
        trace_file="$TRACES_DIR/trace-${trace_file}.json"
    fi

    if [ ! -f "$trace_file" ]; then
        echo -e "${RED}Trace file not found: $trace_file${NC}"
        return 1
    fi

    echo -e "${CYAN}=== Trace Detail: $(basename "$trace_file") ===${NC}"
    echo ""

    if ! has_jq; then
        echo -e "${YELLOW}Install jq for detailed trace analysis${NC}"
        echo "  Raw file: $trace_file"
        return
    fi

    echo -e "${BLUE}Metadata:${NC}"
    jq '.metadata' "$trace_file" 2>/dev/null | sed 's/^/  /'
    echo ""

    echo -e "${BLUE}Event categories:${NC}"
    jq -r '.traceEvents[] | .cat' "$trace_file" 2>/dev/null | sort | uniq -c | sort -rn | head -10 | sed 's/^/  /'
    echo ""

    echo -e "${BLUE}Event types:${NC}"
    jq -r '.traceEvents[] | .name' "$trace_file" 2>/dev/null | sort | uniq -c | sort -rn | head -15 | sed 's/^/  /'
    echo ""

    echo -e "${BLUE}API call performance (last 10):${NC}"
    jq -r '.traceEvents[] | select(.name == "API Call") | select(.ph == "E") |
        "  \(.args.model // "unknown") ttft=\(.args.ttft_ms // "?")ms ttlt=\(.args.ttlt_ms // "?")ms out=\(.args.output_tokens // "?")tok"' \
        "$trace_file" 2>/dev/null | tail -10
    echo ""

    echo -e "${BLUE}Tool executions (last 10):${NC}"
    jq -r '.traceEvents[] | select(.cat == "tool") | select(.ph == "E") |
        "  \(.name) dur=\(.args.duration_ms // "?")ms success=\(.args.success // "?")"' \
        "$trace_file" 2>/dev/null | tail -10
}

# --- Command: events ---
cmd_events() {
    echo -e "${CYAN}=== Analytics Event Registry ===${NC}"
    echo ""

    echo -e "${BLUE}Datadog-allowed events:${NC}"
    grep -oP "'([^']+)'" "$PROJECT_ROOT/src/services/analytics/datadog.ts" 2>/dev/null | \
        grep -E "^'tengu_" | sort -u | sed "s/'//g" | while read -r evt; do
            echo "  $evt"
        done
    echo ""

    echo -e "${BLUE}All logEvent() calls in codebase (unique event names):${NC}"
    grep -rh "logEvent\b" "$PROJECT_ROOT/src/" --include="*.ts" 2>/dev/null | \
        sed -n "s/.*logEvent(['\"]\\([^'\"]*\\).*/\\1/p" | \
        sort -u | while read -r evt; do
            echo "  $evt"
        done
    echo ""

    echo -e "${BLUE}OTel event logger calls:${NC}"
    grep -rh "logOTelEvent\b" "$PROJECT_ROOT/src/" --include="*.ts" 2>/dev/null | \
        sed -n "s/.*logOTelEvent(['\"]\\([^'\"]*\\).*/\\1/p" | \
        sort -u | while read -r evt; do
            echo "  $evt"
        done
    echo ""

    echo -e "${BLUE}OTel span types (sessionTracing):${NC}"
    grep -E "startSpan\(|spanName" "$PROJECT_ROOT/src/utils/telemetry/sessionTracing.ts" 2>/dev/null | \
        grep -oE "'claude_code\.[^']+'" | sort -u | sed "s/'//g" | while read -r span; do
            echo "  $span"
        done
}

# --- Command: session <id> ---
cmd_session() {
    local session_id="${1:-}"
    if [ -z "$session_id" ]; then
        echo "Usage: ./log.sh session <session-id>"
        return 1
    fi

    echo -e "${CYAN}=== Session: $session_id ===${NC}"
    echo ""

    # Check for matching Perfetto trace
    local trace_file="$TRACES_DIR/trace-${session_id}.json"
    if [ -f "$trace_file" ]; then
        echo -e "${GREEN}Perfetto trace found:${NC} $trace_file"
        cmd_trace_detail "$trace_file"
    else
        echo -e "${YELLOW}No Perfetto trace found for session $session_id${NC}"
    fi

    # Search for session ID in source references
    echo -e "${BLUE}Session ID usage in source:${NC}"
    grep -rn "getSessionId\|session.id\|sessionId" \
        "$PROJECT_ROOT/src/utils/telemetry/" \
        --include="*.ts" 2>/dev/null | head -10 | sed 's/^/  /'
    echo ""

    grep -rn "getSessionId\|session.id\|sessionId" \
        "$PROJECT_ROOT/src/services/analytics/" \
        --include="*.ts" 2>/dev/null | head -10 | sed 's/^/  /'
}

# --- Command: grep <pattern> ---
cmd_grep() {
    local pattern="${1:-}"
    if [ -z "$pattern" ]; then
        echo "Usage: ./log.sh grep <pattern>"
        return 1
    fi

    echo -e "${CYAN}=== Searching logs for: $pattern ===${NC}"
    echo ""

    # Search in trace files
    if [ -d "$TRACES_DIR" ]; then
        echo -e "${BLUE}Perfetto traces:${NC}"
        if has_jq; then
            for trace_file in "$TRACES_DIR"/trace-*.json; do
                [ -f "$trace_file" ] || continue
                local matches
                matches=$(jq -r ".traceEvents[] | select(.name | test(\"$pattern\"; \"i\")) |
                    \"  \(.name) [\(.cat)] \(.ph) \(.args // {} | to_entries | map(\"\(.key)=\(.value)\") | join(\" \"))\"" \
                    "$trace_file" 2>/dev/null | head -20)
                if [ -n "$matches" ]; then
                    echo "  In $(basename "$trace_file"):"
                    echo "$matches"
                fi
            done
        else
            grep -rl "$pattern" "$TRACES_DIR"/trace-*.json 2>/dev/null | \
                while read -r f; do echo "  Match in: $f"; done
        fi
        echo ""
    fi

    # Search in source code
    echo -e "${BLUE}Source code matches:${NC}"
    grep -rn "$pattern" \
        "$PROJECT_ROOT/src/utils/telemetry/" \
        "$PROJECT_ROOT/src/services/analytics/" \
        --include="*.ts" 2>/dev/null | head -20 | sed 's/^/  /'
}

# --- Command: summary ---
cmd_summary() {
    echo -e "${CYAN}=== Observability Summary for Open-ClaudeCode ===${NC}"
    echo ""

    echo -e "${BLUE}Project:${NC} Open-ClaudeCode (TypeScript CLI)"
    echo -e "${BLUE}Source files:${NC} $(find "$PROJECT_ROOT/src" -name '*.ts' -not -path '*/node_modules/*' -type f 2>/dev/null | wc -l | tr -d ' ') TypeScript files"
    echo ""

    echo -e "${BLUE}Observability Infrastructure:${NC}"
    echo ""

    # Telemetry module
    local telemetry_files
    telemetry_files=$(find "$PROJECT_ROOT/src/utils/telemetry" -name "*.ts" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  Telemetry module ($telemetry_files files in src/utils/telemetry/):"
    echo "    - instrumentation.ts     : OTEL SDK init (metrics, logs, traces, BigQuery)"
    echo "    - sessionTracing.ts      : Span lifecycle (interaction, LLM, tool, hook)"
    echo "    - perfettoTracing.ts     : Chrome Trace Event format (ant-only)"
    echo "    - betaSessionTracing.ts  : Detailed beta tracing with dedup"
    echo "    - bigqueryExporter.ts    : BigQuery metrics pipeline"
    echo "    - events.ts              : OTel event logger"
    echo "    - pluginTelemetry.ts     : Plugin lifecycle events"
    echo "    - skillLoadedEvent.ts    : Skill availability tracking"
    echo "    - logger.ts              : DiagLogger adapter"
    echo ""

    # Analytics module
    local analytics_files
    analytics_files=$(find "$PROJECT_ROOT/src/services/analytics" -name "*.ts" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  Analytics module ($analytics_files files in src/services/analytics/):"
    echo "    - index.ts                    : Event queue + sink interface"
    echo "    - sink.ts                     : Routing to Datadog + 1P"
    echo "    - datadog.ts                  : Batched Datadog log shipping"
    echo "    - firstPartyEventLogger.ts    : 1P event batch pipeline"
    echo "    - firstPartyEventLoggingExporter.ts : OTel exporter for 1P"
    echo "    - config.ts                   : Analytics opt-out logic"
    echo "    - metadata.ts                 : Event metadata enrichment"
    echo "    - growthbook.ts               : Feature flag integration"
    echo "    - sinkKillswitch.ts           : Emergency sink shutdown"
    echo ""

    # Signals
    echo -e "${BLUE}Enabled signals (environment-controlled):${NC}"
    echo "  CLAUDE_CODE_ENABLE_TELEMETRY           : Enables OTEL metrics+logs+traces"
    echo "  CLAUDE_CODE_ENHANCED_TELEMETRY_BETA     : Enables session tracing spans"
    echo "  ENABLE_BETA_TRACING_DETAILED + BETA_TRACING_ENDPOINT : Beta tracing path"
    echo "  CLAUDE_CODE_PERFETTO_TRACE              : Perfetto Chrome trace output"
    echo "  OTEL_METRICS_EXPORTER                   : console | otlp | prometheus"
    echo "  OTEL_LOGS_EXPORTER                      : console | otlp"
    echo "  OTEL_TRACES_EXPORTER                    : console | otlp"
    echo ""

    # Health
    local trace_count=0
    if [ -d "$TRACES_DIR" ]; then
        trace_count=$(find "$TRACES_DIR" -name "trace-*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    fi
    echo -e "${BLUE}Current state:${NC}"
    echo "  Perfetto traces on disk: $trace_count"
    echo "  jq available: $(has_jq && echo 'yes' || echo 'no (install for structured queries)')"
    echo ""

    # OTEL levels assessment
    echo -e "${BLUE}Observability Level Assessment:${NC}"
    echo "  O1 Feedback  : Level 3 — structured JSON output (OTEL + Perfetto + Datadog)"
    echo "  O2 Persist   : Level 3 — queryable files (traces, batch spill) + BigQuery"
    echo "  O3 Queryable : Level 2 — this script provides grep/jq queries"
    echo "  O4 Attribute : Level 2 — session.id, prompt.id, user.id correlation"
}

# --- Main ---
COMMAND="${1:-summary}"
shift || true

case "$COMMAND" in
    recent)
        cmd_recent
        ;;
    errors)
        cmd_errors
        ;;
    telemetry)
        cmd_telemetry
        ;;
    traces)
        cmd_traces
        ;;
    trace)
        cmd_trace_detail "${1:-}"
        ;;
    events)
        cmd_events
        ;;
    session)
        cmd_session "${1:-}"
        ;;
    grep)
        cmd_grep "${1:-}"
        ;;
    summary)
        cmd_summary
        ;;
    *)
        echo "Open-ClaudeCode Observability Log Query"
        echo ""
        echo "Usage: ./log.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  summary           Overall log health summary"
        echo "  recent            Show recent log activity"
        echo "  errors            Filter for error-level entries"
        echo "  telemetry         Show OTEL telemetry configuration"
        echo "  traces            List Perfetto trace files"
        echo "  trace <file|id>   Summarize a specific Perfetto trace"
        echo "  events            Show analytics event registry"
        echo "  session <id>      Query logs for a specific session"
        echo "  grep <pattern>    Search logs for a pattern"
        echo ""
        echo "Observability: O1=Level3, O2=Level3, O3=Level2, O4=Level2"
        ;;
esac
