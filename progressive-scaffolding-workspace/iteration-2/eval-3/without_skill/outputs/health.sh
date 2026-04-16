#!/bin/bash
# health.sh - Health check script for eval outputs
# Returns JSON with health status

EVAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$EVAL_ROOT/logs"
METRICS_FILE="$EVAL_ROOT/metrics.json"
PID_FILE="$EVAL_ROOT/eval.pid"

mkdir -p "$LOG_DIR"

HEALTH_STATUS='{"status":"unknown","timestamp":"'$(date -Iseconds)'","component":"eval-3-without_skill"}'

# Check outputs directory
if [ -d "$EVAL_ROOT" ]; then
    OUTPUT_COUNT=$(find "$EVAL_ROOT" -type f -name "*.json" -o -name "*.log" -o -name "*.md" 2>/dev/null | wc -l)
    HEALTH_STATUS=$(echo "$HEALTH_STATUS" | sed "s/}$/, \"outputs_count\":$OUTPUT_COUNT}/")
fi

# Check process if PID file exists
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        HEALTH_STATUS=$(echo "$HEALTH_STATUS" | sed "s/}/, \"process_status\":\"running\",\"pid\":$PID}/")
    else
        HEALTH_STATUS=$(echo "$HEALTH_STATUS" | sed "s/}/, \"process_status\":\"not_running\"}/")
    fi
else
    HEALTH_STATUS=$(echo "$HEALTH_STATUS" | sed "s/}/, \"process_status\":\"not_started\"}/")
fi

# Check logs directory for recent activity
if [ -d "$LOG_DIR" ]; then
    LOG_COUNT=$(find "$LOG_DIR" -type f 2>/dev/null | wc -l)
    HEALTH_STATUS=$(echo "$HEALTH_STATUS" | sed "s/}$/, \"log_files\":$LOG_COUNT}/")
fi

echo "$HEALTH_STATUS"