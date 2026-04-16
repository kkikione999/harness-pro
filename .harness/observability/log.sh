#!/bin/bash
# log.sh - Structured log query script
# Usage: ./log.sh recent [count] or ./log.sh search <pattern>

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.harness/observability/logs"

mkdir -p "$LOG_DIR"

COMMAND="${1:-recent}"
COUNT="${2:-50}"

case "$COMMAND" in
    recent)
        echo "=== Recent Logs (last $COUNT lines) ==="
        if ls "$LOG_DIR"/*.log 2>/dev/null | head -1 | grep -q .; then
            ls -t "$LOG_DIR"/*.log | head -1 | xargs tail -n "$COUNT"
        else
            echo "No logs found in $LOG_DIR"
        fi
        ;;
    search)
        PATTERN="${2:-.}"
        echo "=== Search Logs (pattern: $PATTERN) ==="
        grep -r "$PATTERN" "$LOG_DIR"/*.log 2>/dev/null || echo "No matches found"
        ;;
    follow)
        echo "=== Following Logs (Ctrl+C to stop) ==="
        if ls "$LOG_DIR"/*.log 2>/dev/null | head -1 | grep -q .; then
            ls -t "$LOG_DIR"/*.log | head -1 | xargs tail -f
        else
            echo "No logs found"
        fi
        ;;
    *)
        echo "Usage: ./log.sh [recent|search|follow] [args]"
        ;;
esac
