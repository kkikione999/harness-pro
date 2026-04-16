#!/bin/bash
# health.sh - Health check for Open-ClaudeCode
# Returns JSON with health status, OTEL pipeline status, and trace availability.
#
# Usage:
#   ./health.sh              - Full health check (JSON output)
#   ./health.sh --json       - Explicit JSON output
#   ./health.sh --simple     - Just status: healthy/unhealthy
#   ./health.sh --verbose    - Detailed health with all checks

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_CONFIG_HOME="${CLAUDE_CONFIG_HOME:-$HOME/.claude}"
PID_FILE="$PROJECT_ROOT/.harness/open_claude_code.pid"
TIMESTAMP=$(date -Iseconds)

# Parse arguments
MODE="json"
for arg in "$@"; do
    case "$arg" in
        --json) MODE="json" ;;
        --simple) MODE="simple" ;;
        --verbose) MODE="verbose" ;;
    esac
done

# Collect health data
declare -A CHECKS

# Check 1: Is the CLI installed?
CHECKS[cli_installed]="false"
if command -v claude > /dev/null 2>&1; then
    CHECKS[cli_installed]="true"
    CLI_VERSION=$(claude --version 2>/dev/null || echo "unknown")
fi

# Check 2: Node.js runtime
CHECKS[node_runtime]="false"
if command -v node > /dev/null 2>&1; then
    CHECKS[node_runtime]="true"
    NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
fi

# Check 3: Process running (check PID file)
PROCESS_STATUS="not_running"
PID=""
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        PROCESS_STATUS="running"
    else
        PROCESS_STATUS="not_running_stale_pid"
    fi
fi
# Also check for running claude processes
RUNNING_PROCS=$(pgrep -f "claude" 2>/dev/null | head -5 || true)
if [ -n "$RUNNING_PROCS" ]; then
    PROCESS_STATUS="detected"
fi

# Check 4: OTEL telemetry enabled
CHECKS[otel_enabled]="false"
if [ -n "${CLAUDE_CODE_ENABLE_TELEMETRY:-}" ]; then
    CHECKS[otel_enabled]="true"
fi

# Check 5: OTEL endpoint reachable
OTEL_REACHABLE="not_configured"
OTEL_ENDPOINT="${OTEL_EXPORTER_OTLP_ENDPOINT:-}"
if [ -n "$OTEL_ENDPOINT" ]; then
    if command -v curl > /dev/null 2>&1; then
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$OTEL_ENDPOINT" 2>/dev/null || echo "000")
        if [ "$HTTP_CODE" != "000" ]; then
            OTEL_REACHABLE="reachable"
        else
            OTEL_REACHABLE="unreachable"
        fi
    fi
fi

# Check 6: Perfetto traces available
PERFETTO_STATUS="disabled"
TRACE_DIR="$CLAUDE_CONFIG_HOME/traces"
if [ -d "$TRACE_DIR" ]; then
    TRACE_COUNT=$(find "$TRACE_DIR" -name "trace-*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [ "$TRACE_COUNT" -gt 0 ]; then
        PERFETTO_STATUS="traces_available"
    else
        PERFETTO_STATUS="enabled_no_traces"
    fi
fi

# Check 7: Config directory writable
CONFIG_WRITABLE="false"
if [ -d "$CLAUDE_CONFIG_HOME" ] && [ -w "$CLAUDE_CONFIG_HOME" ]; then
    CONFIG_WRITABLE="true"
fi

# Check 8: Project source files integrity
SOURCE_STATUS="unknown"
if [ -d "$PROJECT_ROOT/src" ]; then
    TELEMETRY_DIR="$PROJECT_ROOT/src/utils/telemetry"
    ANALYTICS_DIR="$PROJECT_ROOT/src/services/analytics"
    TELEMETRY_FILES=0
    ANALYTICS_FILES=0
    if [ -d "$TELEMETRY_DIR" ]; then
        TELEMETRY_FILES=$(find "$TELEMETRY_DIR" -type f -name "*.ts" 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ -d "$ANALYTICS_DIR" ]; then
        ANALYTICS_FILES=$(find "$ANALYTICS_DIR" -type f -name "*.ts" 2>/dev/null | wc -l | tr -d ' ')
    fi
    if [ "$TELEMETRY_FILES" -gt 0 ] && [ "$ANALYTICS_FILES" -gt 0 ]; then
        SOURCE_STATUS="healthy"
    else
        SOURCE_STATUS="degraded"
    fi
fi

# Determine overall health
OVERALL="healthy"
if [ "${CHECKS[cli_installed]}" = "false" ] && [ "${CHECKS[node_runtime]}" = "false" ]; then
    OVERALL="unhealthy"
elif [ "$SOURCE_STATUS" = "degraded" ]; then
    OVERALL="degraded"
fi

# Output based on mode
case "$MODE" in
    simple)
        echo "$OVERALL"
        ;;

    json)
        cat <<EOF
{
  "status": "$OVERALL",
  "timestamp": "$TIMESTAMP",
  "project": "open-claudecode",
  "checks": {
    "cli_installed": ${CHECKS[cli_installed]},
    "cli_version": "${CLI_VERSION:-null}",
    "node_runtime": ${CHECKS[node_runtime]},
    "node_version": "${NODE_VERSION:-null}",
    "process_status": "$PROCESS_STATUS",
    "otel_enabled": ${CHECKS[otel_enabled]},
    "otel_endpoint": "$OTEL_REACHABLE",
    "perfetto": "$PERFETTO_STATUS",
    "config_writable": $CONFIG_WRITABLE,
    "source_integrity": "$SOURCE_STATUS",
    "telemetry_files": ${TELEMETRY_FILES:-0},
    "analytics_files": ${ANALYTICS_FILES:-0}
  }
}
EOF
        ;;

    verbose)
        echo "=== Open-ClaudeCode Health Check ==="
        echo "Timestamp: $TIMESTAMP"
        echo "Overall: $OVERALL"
        echo ""
        echo "--- Runtime ---"
        echo "  CLI installed: ${CHECKS[cli_installed]}"
        [ -n "${CLI_VERSION:-}" ] && echo "  CLI version: $CLI_VERSION"
        echo "  Node runtime: ${CHECKS[node_runtime]}"
        [ -n "${NODE_VERSION:-}" ] && echo "  Node version: $NODE_VERSION"
        echo "  Process: $PROCESS_STATUS"
        [ -n "$RUNNING_PROCS" ] && echo "  Running PIDs: $(echo $RUNNING_PROCS | tr '\n' ' ')"
        echo ""
        echo "--- Telemetry ---"
        echo "  OTEL enabled: ${CHECKS[otel_enabled]}"
        echo "  OTEL endpoint: $OTEL_REACHABLE"
        echo "  Metrics exporter: ${OTEL_METRICS_EXPORTER:-<not set>}"
        echo "  Logs exporter: ${OTEL_LOGS_EXPORTER:-<not set>}"
        echo "  Traces exporter: ${OTEL_TRACES_EXPORTER:-<not set>}"
        echo "  Perfetto: $PERFETTO_STATUS"
        [ "$PERFETTO_STATUS" = "traces_available" ] && echo "  Trace count: $TRACE_COUNT"
        echo ""
        echo "--- Infrastructure ---"
        echo "  Config dir writable: $CONFIG_WRITABLE"
        echo "  Source integrity: $SOURCE_STATUS"
        echo "  Telemetry source files: ${TELEMETRY_FILES:-0}"
        echo "  Analytics source files: ${ANALYTICS_FILES:-0}"
        echo ""
        echo "--- Telemetry Components ---"
        echo "  src/utils/telemetry/ :"
        echo "    - instrumentation.ts (OTEL SDK init)"
        echo "    - sessionTracing.ts (interaction/LLM/tool spans)"
        echo "    - bigqueryExporter.ts (BigQuery metrics pipeline)"
        echo "    - perfettoTracing.ts (Chrome trace format)"
        echo "    - events.ts (OTEL event logging)"
        echo "    - logger.ts (DiagLogger adapter)"
        echo "  src/services/analytics/ :"
        echo "    - index.ts (event queue + sink attach)"
        echo "    - sink.ts (Datadog + 1P routing)"
        echo "    - datadog.ts (Datadog log shipping)"
        echo "    - firstPartyEventLogger.ts (1P batch events)"
        echo "    - firstPartyEventLoggingExporter.ts (OTEL exporter for 1P)"
        echo "    - sinkKillswitch.ts (emergency shutoff)"
        ;;
esac

# Exit with semantic code
case "$OVERALL" in
    healthy)   exit 0 ;;
    degraded)  exit 1 ;;
    unhealthy) exit 2 ;;
esac
