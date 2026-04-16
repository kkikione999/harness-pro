#!/bin/bash
# log.sh - Structured log query script for harness-blogs

set -e

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HARNESS_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.harness/logs"

# Default values
FORMAT="text"  # text, json
SINCE="1h"
PATTERN=""
LIMIT=100

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        --pattern)
            PATTERN="$2"
            shift 2
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        recent)
            SINCE="1h"
            shift
            ;;
        all)
            SINCE="all"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Ensure log directory exists
mkdir -p "$LOG_DIR"

CORRELATION_ID="log-$$-$(date +%Y%m%d-%H%M%S)"

echo "=== Log Query ===" if [ "$FORMAT" = "text" ]; then
    echo "Correlation ID: $CORRELATION_ID"
    echo "Since: $SINCE"
    echo "Pattern: ${PATTERN:-none}"
    echo ""

    if [ "$SINCE" = "all" ]; then
        echo "Showing all logs (last $LIMIT entries):"
    else
        echo "Showing logs from last $SINCE (last $LIMIT entries):"
    fi

    # Check if logs exist
    if [ ! -d "$LOG_DIR" ] || [ -z "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
        echo "  (No logs found - log directory is empty)"
        echo ""
        echo "To create logs, add logging to your scripts:"
        echo "  echo '[\$(date -Iseconds)] [INFO] message' >> $LOG_DIR/app.log"
    else
        # Find log files and search
        find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | while read -r logfile; do
            echo "--- $logfile ---"
            if [ -n "$PATTERN" ]; then
                grep -i "$PATTERN" "$logfile" 2>/dev/null | tail -n "$LIMIT" || echo "  (no matching entries)"
            else
                tail -n "$LIMIT" "$logfile" 2>/dev/null || echo "  (empty)"
            fi
        done
    fi
elif [ "$FORMAT" = "json" ]; then
    # JSON output
    LOG_ENTRIES=()

    if [ -d "$LOG_DIR" ] && [ -n "$(ls -A "$LOG_DIR" 2>/dev/null)" ]; then
        find "$LOG_DIR" -name "*.log" -type f 2>/dev/null | while read -r logfile; do
            while IFS= read -r line; do
                # Parse simple timestamp format [ISO8601] [LEVEL] message
                TIMESTAMP=$(echo "$line" | grep -oP '^\[\K[^\]]+' || echo "$(date -Iseconds)")
                LEVEL=$(echo "$line" | grep -oP '\]\s*\[\K[^\]]+' || echo "INFO")
                MESSAGE=$(echo "$line" | sed 's/^\[[^]]*\]\s*\[[^]]*\]\s*//' || echo "$line")

                LOG_ENTRIES+=("{\"timestamp\": \"$TIMESTAMP\", \"level\": \"$LEVEL\", \"message\": \"$MESSAGE\", \"source\": \"$logfile\"}")
            done < <(tail -n "$LIMIT" "$logfile" 2>/dev/null || true)
        done
    fi

    # Output JSON
    printf '%s\n' '{"correlation_id": "'$CORRELATION_ID'", "timestamp": "'$(date -Iseconds)'", "format": "json", "count": '${#LOG_ENTRIES[@]}', "logs": ['
    FIRST=true
    for entry in "${LOG_ENTRIES[@]}"; do
        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            printf ','
        fi
        printf '%s' "$entry"
    done
    printf '\n]}'
fi

echo ""
exit 0
