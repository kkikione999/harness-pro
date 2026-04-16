#!/bin/bash
# verify.sh - Health check script
# Returns 0 if healthy, non-zero if unhealthy

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="$PROJECT_ROOT/.harness/{{project-name}}.pid"

# Check if process is running
if [ ! -f "$PID_FILE" ]; then
    echo "✗ No PID file found - service not running?"
    exit 1
fi

PID=$(cat "$PID_FILE")
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "✗ Process $PID not running"
    exit 1
fi

# Check health endpoint if available
if [ -f "$PROJECT_ROOT/.env" ]; then
    source "$PROJECT_ROOT/.env"
fi

HEALTH_ENDPOINT="${HEALTH_ENDPOINT:-http://localhost:8080/health}"
CURL_TIMEOUT="${CURL_TIMEOUT:-5}"

if command -v curl > /dev/null 2>&1; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$CURL_TIMEOUT" "$HEALTH_ENDPOINT" 2>/dev/null || echo "000")
    if [ "$HTTP_CODE" = "200" ]; then
        echo "✓ Service healthy (HTTP $HTTP_CODE)"
        exit 0
    else
        echo "✗ Health check failed (HTTP $HTTP_CODE)"
        exit 1
    fi
else
    echo "✓ Process $PID is running (no HTTP health check)"
    exit 0
fi
