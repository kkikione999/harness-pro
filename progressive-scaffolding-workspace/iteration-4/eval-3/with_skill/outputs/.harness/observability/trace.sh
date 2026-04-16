#!/bin/bash
# trace.sh - Correlation ID injection and tracing control for Open-ClaudeCode
# Injects correlation/trace IDs and wraps commands with OTEL context propagation.
#
# Usage:
#   ./trace.sh <command> [args...]          - Run command with correlation ID
#   ./trace.sh --id <trace-id> <command>    - Use specific trace ID
#   ./trace.sh --spans                      - Show active span types
#   ./trace.sh --sessions                   - Show session trace information
#   ./trace.sh --inject                     - Print environment variables for injection

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_CONFIG_HOME="${CLAUDE_CONFIG_HOME:-$HOME/.claude}"

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $*"; }

# Handle subcommands first
case "${1:-}" in
    --spans)
        echo "=== Open-ClaudeCode Span Types ==="
        echo ""
        echo "The session tracing system (src/utils/telemetry/sessionTracing.ts)"
        echo "manages these span types via OpenTelemetry:"
        echo ""
        echo "  interaction            Root span wrapping user request -> response cycle"
        echo "    - interaction.sequence: monotonically increasing counter"
        echo "    - user_prompt: REDACTED unless OTEL_LOG_USER_PROMPTS=1"
        echo "    - interaction.duration_ms: total interaction time"
        echo ""
        echo "  llm_request            LLM API call span"
        echo "    - model: model identifier"
        echo "    - input_tokens, output_tokens"
        echo "    - cache_read_tokens, cache_creation_tokens"
        echo "    - ttft_ms (time to first token)"
        echo "    - success, status_code, error"
        echo "    - response.has_tool_call"
        echo ""
        echo "  tool                    Tool invocation span"
        echo "    - tool_name: name of the tool"
        echo "    - duration_ms, result_tokens"
        echo ""
        echo "  tool.blocked_on_user   Permission request span"
        echo "    - decision: accept/reject"
        echo "    - source: prompt/temporary/permanent"
        echo ""
        echo "  tool.execution         Actual tool execution sub-span"
        echo "    - success, error, duration_ms"
        echo ""
        echo "  hook                   Hook execution span (beta tracing only)"
        echo "    - hook_event: PreToolUse/PostToolUse/etc."
        echo "    - hook_name: full hook identifier"
        echo "    - num_success, num_blocking, num_non_blocking_error, num_cancelled"
        echo ""
        echo "Span hierarchy:"
        echo "  interaction -> tool -> tool.blocked_on_user"
        echo "  interaction -> tool -> tool.execution"
        echo "  interaction -> llm_request"
        echo "  interaction -> hook"
        echo ""
        echo "Tracing activation:"
        echo "  Standard: CLAUDE_CODE_ENABLE_TELEMETRY=1 + OTEL_TRACES_EXPORTER=otlp"
        echo "  Enhanced: ENABLE_ENHANCED_TELEMETRY_BETA=1"
        echo "  Beta:     BETA_TRACING_ENDPOINT=<url>"
        echo "  Perfetto: CLAUDE_CODE_PERFETTO_TRACE=1"
        exit 0
        ;;

    --sessions)
        echo "=== Session Trace Information ==="
        echo ""

        # Check for Perfetto traces
        TRACE_DIR="$CLAUDE_CONFIG_HOME/traces"
        if [ -d "$TRACE_DIR" ]; then
            TRACE_FILES=$(find "$TRACE_DIR" -name "trace-*.json" -type f 2>/dev/null | sort -r)
            TRACE_COUNT=$(echo "$TRACE_FILES" | wc -l | tr -d ' ')
            log_info "Perfetto traces: $TRACE_COUNT sessions"

            if [ "$TRACE_COUNT" -gt 0 ]; then
                echo ""
                echo "Recent traces:"
                echo "$TRACE_FILES" | head -5 | while read -r f; do
                    [ -z "$f" ] && continue
                    SIZE=$(du -h "$f" 2>/dev/null | cut -f1)
                    MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$f" 2>/dev/null || stat -c "%y" "$f" 2>/dev/null | cut -d'.' -f1)
                    # Extract session ID from filename
                    SESSION_ID=$(basename "$f" | sed 's/trace-\(.*\)\.json/\1/')
                    echo "  $SESSION_ID  $SIZE  $MODIFIED"
                done

                echo ""
                log_info "Open traces at: https://ui.perfetto.dev"
            fi
        else
            log_warn "No Perfetto traces found"
            log_info "Enable with: CLAUDE_CODE_PERFETTO_TRACE=1"
        fi
        echo ""

        # Check for correlation ID history
        LOG_DIR="$PROJECT_ROOT/.harness/observability/logs"
        if [ -d "$LOG_DIR" ] && ls "$LOG_DIR"/*.log 2>/dev/null | head -1 | grep -q .; then
            log_info "Correlation IDs in harness logs:"
            grep -oh '\[trace-[a-zA-Z0-9-]*\]' "$LOG_DIR"/*.log 2>/dev/null | sort -u | tail -10 || true
        fi
        exit 0
        ;;

    --inject)
        echo "=== Trace Environment Variables for Injection ==="
        echo ""
        echo "# Core telemetry"
        echo "export CLAUDE_CODE_ENABLE_TELEMETRY=1"
        echo ""
        echo "# OTEL Exporter configuration"
        echo "export OTEL_EXPORTER_OTLP_ENDPOINT=${OTEL_EXPORTER_OTLP_ENDPOINT:-http://localhost:4318}"
        echo "export OTEL_EXPORTER_OTLP_PROTOCOL=${OTEL_EXPORTER_OTLP_PROTOCOL:-http/json}"
        echo ""
        echo "# Signal-specific exporters"
        echo "export OTEL_METRICS_EXPORTER=${OTEL_METRICS_EXPORTER:-console}"
        echo "export OTEL_LOGS_EXPORTER=${OTEL_LOGS_EXPORTER:-console}"
        echo "export OTEL_TRACES_EXPORTER=${OTEL_TRACES_EXPORTER:-console}"
        echo ""
        echo "# Enhanced telemetry (session tracing)"
        echo "export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1"
        echo ""
        echo "# Perfetto tracing (Chrome trace format)"
        echo "export CLAUDE_CODE_PERFETTO_TRACE=1"
        echo "# Or with custom path:"
        echo "# export CLAUDE_CODE_PERFETTO_TRACE=/path/to/trace.json"
        echo ""
        echo "# Beta tracing (separate endpoint)"
        echo "export ENABLE_BETA_TRACING_DETAILED=1"
        echo "export BETA_TRACING_ENDPOINT=http://localhost:4318"
        echo ""
        echo "# Content logging (debugging only)"
        echo "export OTEL_LOG_USER_PROMPTS=1"
        echo "export OTEL_LOG_TOOL_CONTENT=1"
        echo ""
        echo "# Correlation ID (auto-generated if not set)"
        echo "export CORRELATION_ID=${CORRELATION_ID:-}"
        echo ""
        echo "# Shutdown timeout"
        echo "export CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS=${CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS:-2000}"
        exit 0
        ;;
esac

# Default: wrap a command with correlation ID
CUSTOM_ID=""
if [ "${1:-}" = "--id" ]; then
    CUSTOM_ID="$2"
    shift 2
fi

if [ $# -eq 0 ]; then
    echo "Usage: ./trace.sh [options] <command> [args...]"
    echo ""
    echo "Options:"
    echo "  --id <trace-id>   Use specific trace/correlation ID"
    echo "  --spans           Show available span types"
    echo "  --sessions        Show session trace information"
    echo "  --inject          Print env vars for trace injection"
    echo ""
    echo "Examples:"
    echo "  ./trace.sh npm test"
    echo "  ./trace.sh --id custom-trace-123 npm test"
    echo "  ./trace.sh --spans"
    exit 1
fi

# Generate correlation ID
CORRELATION_ID="${CUSTOM_ID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || echo "trace-$(date +%s)")}"
export CORRELATION_ID

# Log to harness observability log
LOG_DIR="$PROJECT_ROOT/.harness/observability/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/trace-$(date +%Y%m%d).log"

echo "[$(date -Iseconds)] [$CORRELATION_ID] START: $*" >> "$LOG_FILE"

log_info "[$CORRELATION_ID] Starting: $*"

# Run the command
set +e
"$@"
EXIT_CODE=$?
set -e

# Log result
echo "[$(date -Iseconds)] [$CORRELATION_ID] END: exit_code=$EXIT_CODE" >> "$LOG_FILE"

if [ $EXIT_CODE -eq 0 ]; then
    log_info "[$CORRELATION_ID] Finished successfully"
else
    log_error "[$CORRELATION_ID] Finished with exit code: $EXIT_CODE"
fi

exit $EXIT_CODE
