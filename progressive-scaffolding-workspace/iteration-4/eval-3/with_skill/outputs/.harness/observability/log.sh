#!/bin/bash
# log.sh - Structured log query script for Open-ClaudeCode
# Queries telemetry debug logs, session traces, and Datadog event logs.
#
# Usage:
#   ./log.sh recent [count]          - Show recent debug log entries
#   ./log.sh search <pattern>        - Search logs for a pattern
#   ./log.sh follow                  - Tail the latest log in real time
#   ./log.sh events [count]          - Show recent analytics events
#   ./log.sh telemetry               - Show OTEL telemetry status
#   ./log.sh perfetto                - Show Perfetto trace status

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.harness/observability/logs"
CLAUDE_CONFIG_HOME="${CLAUDE_CONFIG_HOME:-$HOME/.claude}"

mkdir -p "$LOG_DIR"

COMMAND="${1:-recent}"
COUNT="${2:-50}"

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $*"; }

# Discover available debug log files from Claude Code internals
# The project uses logForDebugging() which writes to a debug log channel
find_debug_logs() {
    # Check for session-level debug logs in .claude directory
    find "$CLAUDE_CONFIG_HOME" -name "*.log" -type f 2>/dev/null | head -20
    # Check for harness-managed logs
    find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | head -10
}

case "$COMMAND" in
    recent)
        echo "=== Recent Logs (last $COUNT lines) ==="
        LOGS_FOUND=false

        # Check harness-managed logs first
        if ls "$LOG_DIR"/*.log 2>/dev/null | head -1 | grep -q .; then
            log_info "Harness logs:"
            ls -t "$LOG_DIR"/*.log | head -1 | xargs tail -n "$COUNT"
            LOGS_FOUND=true
        fi

        # Check Claude config debug logs
        if [ -d "$CLAUDE_CONFIG_HOME" ]; then
            CLAUDE_LOGS=$(find "$CLAUDE_CONFIG_HOME" -name "*.log" -type f -mtime -1 2>/dev/null | head -5)
            if [ -n "$CLAUDE_LOGS" ]; then
                log_info "Claude config logs (last 24h):"
                echo "$CLAUDE_LOGS" | while read -r f; do
                    echo "--- $f ---"
                    tail -n "$COUNT" "$f"
                done
                LOGS_FOUND=true
            fi
        fi

        if [ "$LOGS_FOUND" = false ]; then
            log_warn "No logs found"
            log_info "Logs are captured when CLAUDE_CODE_ENABLE_TELEMETRY=1 is set"
            log_info "Debug logs appear in: $CLAUDE_CONFIG_HOME/"
            log_info "Harness logs appear in: $LOG_DIR/"
        fi
        ;;

    search)
        PATTERN="${2:-.}"
        echo "=== Search Logs (pattern: $PATTERN) ==="
        RESULTS=0

        # Search harness logs
        if ls "$LOG_DIR"/*.log 2>/dev/null | head -1 | grep -q .; then
            MATCHES=$(grep -r "$PATTERN" "$LOG_DIR"/*.log 2>/dev/null || true)
            if [ -n "$MATCHES" ]; then
                log_info "Harness log matches:"
                echo "$MATCHES"
                RESULTS=$((RESULTS + 1))
            fi
        fi

        # Search Claude config logs
        if [ -d "$CLAUDE_CONFIG_HOME" ]; then
            MATCHES=$(grep -r "$PATTERN" "$CLAUDE_CONFIG_HOME"/*.log 2>/dev/null || true)
            if [ -n "$MATCHES" ]; then
                log_info "Claude config log matches:"
                echo "$MATCHES" | head -n "$COUNT"
                RESULTS=$((RESULTS + 1))
            fi
        fi

        if [ "$RESULTS" -eq 0 ]; then
            log_warn "No matches found for pattern: $PATTERN"
        fi
        ;;

    follow)
        echo "=== Following Logs (Ctrl+C to stop) ==="
        if ls "$LOG_DIR"/*.log 2>/dev/null | head -1 | grep -q .; then
            LATEST_LOG=$(ls -t "$LOG_DIR"/*.log | head -1)
            log_info "Following: $LATEST_LOG"
            tail -f "$LATEST_LOG"
        else
            log_warn "No harness logs found. Running a command with log capture first."
            log_info "To capture logs: CORRELATION_ID=test-$(date +%s) ./trace.sh <command>"
        fi
        ;;

    events)
        EVENT_COUNT="${2:-20}"
        echo "=== Recent Analytics Events (last $EVENT_COUNT) ==="
        log_info "Open-ClaudeCode routes events through these sinks:"
        echo ""
        echo "  1. Datadog (tengu_* events)"
        echo "     Endpoint: https://http-intake.logs.us5.datadoghq.com/api/v2/logs"
        echo "     Gate: tengu_log_datadog_events"
        echo "     Source: src/services/analytics/datadog.ts"
        echo ""
        echo "  2. 1P Event Logging (batched)"
        echo "     Endpoint: /api/event_logging/batch"
        echo "     Source: src/services/analytics/firstPartyEventLogger.ts"
        echo ""
        echo "  3. OpenTelemetry (CLAUDE_CODE_ENABLE_TELEMETRY=1)"
        echo "     Exporters: console, otlp, prometheus"
        echo "     Source: src/utils/telemetry/instrumentation.ts"
        echo ""

        # Check event logging status
        if [ -n "${CLAUDE_CODE_ENABLE_TELEMETRY:-}" ]; then
            log_info "OTEL Telemetry: ENABLED"
            log_info "  Metrics exporter: ${OTEL_METRICS_EXPORTER:-not set}"
            log_info "  Logs exporter: ${OTEL_LOGS_EXPORTER:-not set}"
            log_info "  Traces exporter: ${OTEL_TRACES_EXPORTER:-not set}"
        else
            log_warn "OTEL Telemetry: DISABLED (set CLAUDE_CODE_ENABLE_TELEMETRY=1)"
        fi
        ;;

    telemetry)
        echo "=== Telemetry Infrastructure Status ==="
        echo ""

        # Check OTEL configuration
        log_info "OpenTelemetry Configuration:"
        echo "  CLAUDE_CODE_ENABLE_TELEMETRY: ${CLAUDE_CODE_ENABLE_TELEMETRY:-<not set>}"
        echo "  OTEL_EXPORTER_OTLP_ENDPOINT: ${OTEL_EXPORTER_OTLP_ENDPOINT:-<not set>}"
        echo "  OTEL_EXPORTER_OTLP_PROTOCOL: ${OTEL_EXPORTER_OTLP_PROTOCOL:-<not set>}"
        echo "  OTEL_METRICS_EXPORTER: ${OTEL_METRICS_EXPORTER:-<not set>}"
        echo "  OTEL_LOGS_EXPORTER: ${OTEL_LOGS_EXPORTER:-<not set>}"
        echo "  OTEL_TRACES_EXPORTER: ${OTEL_TRACES_EXPORTER:-<not set>}"
        echo ""

        # Check enhanced telemetry
        log_info "Enhanced Telemetry (Session Tracing):"
        echo "  CLAUDE_CODE_ENHANCED_TELEMETRY_BETA: ${CLAUDE_CODE_ENHANCED_TELEMETRY_BETA:-<not set>}"
        echo "  ENABLE_ENHANCED_TELEMETRY_BETA: ${ENABLE_ENHANCED_TELEMETRY_BETA:-<not set>}"
        echo "  Source: src/utils/telemetry/sessionTracing.ts"
        echo ""

        # Check Perfetto tracing
        log_info "Perfetto Tracing:"
        PERFETTO_STATUS="disabled"
        if [ -n "${CLAUDE_CODE_PERFETTO_TRACE:-}" ]; then
            PERFETTO_STATUS="enabled"
            log_info "  CLAUDE_CODE_PERFETTO_TRACE: $CLAUDE_CODE_PERFETTO_TRACE"
            log_info "  Write interval: ${CLAUDE_CODE_PERFETTO_WRITE_INTERVAL_S:-default (on exit)}"
        else
            log_warn "  CLAUDE_CODE_PERFETTO_TRACE: <not set>"
        fi
        echo "  Source: src/utils/telemetry/perfettoTracing.ts"
        echo ""

        # Check BigQuery metrics
        log_info "BigQuery Metrics Exporter:"
        echo "  Enabled for: API customers, C4E users, Teams users"
        echo "  Source: src/utils/telemetry/bigqueryExporter.ts"
        echo ""

        # Check Datadog
        log_info "Datadog Analytics:"
        echo "  NODE_ENV: ${NODE_ENV:-<not set>}"
        echo "  Source: src/services/analytics/datadog.ts"
        ;;

    perfetto)
        echo "=== Perfetto Trace Status ==="
        echo ""

        if [ -z "${CLAUDE_CODE_PERFETTO_TRACE:-}" ]; then
            log_warn "Perfetto tracing is not enabled"
            log_info "Enable with: CLAUDE_CODE_PERFETTO_TRACE=1"
            log_info "Or specify path: CLAUDE_CODE_PERFETTO_TRACE=/path/to/trace.json"
            echo ""
            log_info "Then open the trace file at https://ui.perfetto.dev"
        else
            log_info "Perfetto tracing is ENABLED"

            # Determine trace file location
            TRACE_DIR="$CLAUDE_CONFIG_HOME/traces"
            if [ -d "$TRACE_DIR" ]; then
                log_info "Trace directory: $TRACE_DIR"
                TRACE_COUNT=$(find "$TRACE_DIR" -name "trace-*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
                log_info "Trace files: $TRACE_COUNT"

                LATEST_TRACE=$(ls -t "$TRACE_DIR"/trace-*.json 2>/dev/null | head -1)
                if [ -n "$LATEST_TRACE" ]; then
                    log_info "Latest trace: $LATEST_TRACE"
                    TRACE_SIZE=$(du -h "$LATEST_TRACE" | cut -f1)
                    echo "  Size: $TRACE_SIZE"

                    # Parse event count from trace metadata
                    if command -v python3 > /dev/null 2>&1; then
                        EVENT_COUNT=$(python3 -c "
import json, sys
try:
    with open('$LATEST_TRACE') as f:
        data = json.load(f)
    total = data.get('metadata', {}).get('total_event_count', 'unknown')
    print(total)
except:
    print('unknown')
" 2>/dev/null || echo "unknown")
                        echo "  Events: $EVENT_COUNT"
                    fi
                fi
            else
                log_warn "Trace directory not found: $TRACE_DIR"
            fi
        fi

        echo ""
        log_info "Perfetto trace events include:"
        echo "  - Interaction spans (user request -> response)"
        echo "  - LLM request spans (model, TTFT, tokens, cache stats)"
        echo "  - Tool execution spans (tool name, duration, tokens)"
        echo "  - User input waiting spans"
        echo "  - Agent hierarchy (parent-child swarm relationships)"
        ;;

    *)
        echo "Usage: ./log.sh [recent|search|follow|events|telemetry|perfetto] [args]"
        echo ""
        echo "Commands:"
        echo "  recent [count]    Show recent log entries (default: 50)"
        echo "  search <pattern>  Search logs for a pattern"
        echo "  follow            Tail the latest log in real time"
        echo "  events [count]    Show analytics event routing info"
        echo "  telemetry         Show OTEL telemetry configuration"
        echo "  perfetto          Show Perfetto trace status"
        ;;
esac
