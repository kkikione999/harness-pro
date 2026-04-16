#!/bin/bash
# log.sh - Structured log query script for Open-ClaudeCode harness
# Usage:
#   ./log.sh recent [count]       - Show last N lines of most recent log
#   ./log.sh search <pattern>     - Search logs for a pattern
#   ./log.sh follow               - Tail the most recent log
#   ./log.sh list                 - List all log files
#   ./log.sh summary              - Show pass/fail summary from all logs

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.harness/observability/logs"

mkdir -p "$LOG_DIR"

COMMAND="${1:-recent}"
COUNT="${2:-50}"

case "$COMMAND" in
    recent)
        echo "=== Recent Logs (last $COUNT lines) ==="
        LATEST=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            echo "File: $(basename "$LATEST")"
            tail -n "$COUNT" "$LATEST"
        else
            echo "No logs found in $LOG_DIR"
            echo "Run 'make test-auto' to generate logs"
        fi
        ;;
    search)
        PATTERN="${2:-.}"
        echo "=== Search Logs (pattern: $PATTERN) ==="
        FOUND=0
        for logfile in "$LOG_DIR"/*.log; do
            [ -f "$logfile" ] || continue
            MATCHES=$(grep -c "$PATTERN" "$logfile" 2>/dev/null || echo 0)
            if [ "$MATCHES" -gt 0 ]; then
                echo "--- $(basename "$logfile") ($MATCHES matches) ---"
                grep "$PATTERN" "$logfile"
                FOUND=1
            fi
        done
        [ "$FOUND" -eq 0 ] && echo "No matches found"
        ;;
    follow)
        LATEST=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -1)
        if [ -n "$LATEST" ]; then
            echo "=== Following: $(basename "$LATEST") ==="
            tail -f "$LATEST"
        else
            echo "No logs found"
        fi
        ;;
    list)
        echo "=== Log Files ==="
        if ls "$LOG_DIR"/*.log 2>/dev/null | head -1 | grep -q .; then
            for logfile in "$LOG_DIR"/*.log; do
                SIZE=$(wc -c < "$logfile" | tr -d ' ')
                LINES=$(wc -l < "$logfile" | tr -d ' ')
                echo "  $(basename "$logfile") ($SIZE bytes, $LINES lines)"
            done
        else
            echo "  No log files found"
        fi
        ;;
    summary)
        echo "=== Test Log Summary ==="
        TOTAL=0
        PASSED=0
        FAILED=0
        for logfile in "$LOG_DIR"/test-auto-*.log; do
            [ -f "$logfile" ] || continue
            TOTAL=$((TOTAL + 1))
            if grep -q "PASSED\|All.*passed\|RESULT: All" "$logfile" 2>/dev/null; then
                PASSED=$((PASSED + 1))
                echo "  PASS $(basename "$logfile")"
            else
                FAILED=$((FAILED + 1))
                echo "  FAIL $(basename "$logfile")"
            fi
        done
        echo ""
        echo "Total runs: $TOTAL | Passed: $PASSED | Failed: $FAILED"
        ;;
    *)
        echo "Usage: ./log.sh [recent|search|follow|list|summary] [args]"
        echo ""
        echo "Commands:"
        echo "  recent [N]        Show last N lines of most recent log (default: 50)"
        echo "  search <pattern>  Search all logs for a regex pattern"
        echo "  follow            Tail the most recent log in real time"
        echo "  list              List all log files with sizes"
        echo "  summary           Show pass/fail summary of all test runs"
        ;;
esac
