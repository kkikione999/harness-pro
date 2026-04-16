#!/bin/bash
# log.sh - Structured log query for Open-ClaudeCode
# Usage: ./log.sh [recent|search|follow|telemetry|attributes|cost] [args]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
OUTPUT_BASE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
LOG_DIR="$OUTPUT_BASE/.harness/observability/logs"
CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "log-$(date +%s)")}"

mkdir -p "$LOG_DIR"

COMMAND="${1:-recent}"
COUNT="${2:-50}"

echo "[$CORRELATION_ID] log.sh invoked: $COMMAND $COUNT" >&2

case "$COMMAND" in
    recent)
        echo "=== Recent Logs (last $COUNT lines) ==="
        if ls "$LOG_DIR"/*.log 2>/dev/null | head -1 | grep -q .; then
            ls -t "$LOG_DIR"/*.log | head -1 | xargs tail -n "$COUNT"
        else
            echo "No logs found in $LOG_DIR"
            echo ""
            echo "Note: Start the CLI with .harness/controllability/start.sh to generate logs."
            echo "Open-ClaudeCode has telemetry at src/utils/telemetry/ and src/services/analytics/"
        fi
        ;;

    search)
        PATTERN="${2:-.}"
        echo "=== Search Logs (pattern: $PATTERN) ==="
        if ls "$LOG_DIR"/*.log 2>/dev/null | head -1 | grep -q .; then
            grep -r "$PATTERN" "$LOG_DIR"/*.log 2>/dev/null || echo "No matches found"
        else
            echo "No log files to search"
        fi
        ;;

    follow)
        echo "=== Following Logs (Ctrl+C to stop) ==="
        if ls "$LOG_DIR"/*.log 2>/dev/null | head -1 | grep -q .; then
            ls -t "$LOG_DIR"/*.log | head -1 | xargs tail -f
        else
            echo "No log files found"
        fi
        ;;

    telemetry)
        # Query telemetry infrastructure
        echo "=== Telemetry Infrastructure ==="
        echo "Open-ClaudeCode telemetry files:"
        find "$PROJECT_ROOT/src" -type f \( -name "*telemetry*" -o -name "*analytics*" -o -name "*cost*" \) 2>/dev/null | head -20 | while read -r f; do
            echo "  - $f"
        done
        echo ""
        echo "Key telemetry attributes (from telemetryAttributes.ts):"
        if [ -f "$PROJECT_ROOT/src/utils/telemetryAttributes.ts" ]; then
            grep -E "export|interface|type" "$PROJECT_ROOT/src/utils/telemetryAttributes.ts" 2>/dev/null | head -20
        fi
        ;;

    attributes)
        # Show structured telemetry attributes
        echo "=== Telemetry Attributes ==="
        if [ -f "$PROJECT_ROOT/src/utils/telemetryAttributes.ts" ]; then
            cat "$PROJECT_ROOT/src/utils/telemetryAttributes.ts"
        else
            echo "telemetryAttributes.ts not found"
        fi
        ;;

    cost)
        # Query cost tracking
        echo "=== Cost Tracking ==="
        if [ -f "$PROJECT_ROOT/src/cost-tracker.ts" ]; then
            echo "Found: src/cost-tracker.ts"
            grep -E "export|interface|type|class|function" "$PROJECT_ROOT/src/cost-tracker.ts" | head -15
        fi
        if [ -f "$PROJECT_ROOT/src/costHook.ts" ]; then
            echo ""
            echo "Found: src/costHook.ts"
            grep -E "export|interface|type|class|function" "$PROJECT_ROOT/src/costHook.ts" | head -15
        fi
        ;;

    *)
        echo "Usage: ./log.sh [recent|search|follow|telemetry|attributes|cost] [args]"
        echo ""
        echo "Commands:"
        echo "  recent     [N]    - Show last N log lines (default: 50)"
        echo "  search     <pat> - Search logs for pattern"
        echo "  follow            - Follow latest log file"
        echo "  telemetry          - List telemetry infrastructure"
        echo "  attributes         - Show telemetry attributes schema"
        echo "  cost               - Show cost tracking utilities"
        ;;
esac
