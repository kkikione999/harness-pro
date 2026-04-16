#!/bin/bash
# health.sh - Health check script
# Returns JSON with health status

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="$PROJECT_ROOT/.harness/open_claude_code.pid"

HEALTH_STATUS='{"status":"unknown","timestamp":"'$(date -Iseconds)'"}'

# Check process
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        HEALTH_STATUS='{"status":"running","pid":'$PID',"timestamp":"'$(date -Iseconds)'"}'
    else
        HEALTH_STATUS='{"status":"not_running","pid_file_exists":true,"timestamp":"'$(date -Iseconds)'"}'
    fi
else
    HEALTH_STATUS='{"status":"not_running","pid_file_exists":false,"timestamp":"'$(date -Iseconds)'"}'
fi

# Check HTTP if available
HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-http://localhost:8080/health}"
if command -v curl > /dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$HEALTH_ENDPOINT" 2>/dev/null || echo "000")
    HEALTH_STATUS=$(echo "$HEALTH_STATUS" | sed "s/}$/, \"http_status\":$HTTP_CODE}/")
fi

echo "$HEALTH_STATUS"
