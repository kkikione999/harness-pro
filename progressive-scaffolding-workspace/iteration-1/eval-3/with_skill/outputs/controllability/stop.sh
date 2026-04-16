#!/bin/bash
# stop.sh - Stop the development server for harness-blogs

set -e

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HARNESS_DIR/.." && pwd)"

CORRELATION_ID="stop-$$-$(date +%Y%m%d-%H%M%S)"

# Check for PID file
if [ -f "$HARNESS_DIR/.server.pid" ]; then
    PID=$(cat "$HARNESS_DIR/.server.pid")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Stopping server (PID: $PID)..."
        kill "$PID"
        rm -f "$HARNESS_DIR/.server.pid"
        echo "Server stopped at $(date)"
    else
        echo "Server not running (stale PID file)"
        rm -f "$HARNESS_DIR/.server.pid"
    fi
else
    echo "No PID file found. Server may not be running."
fi

echo "Correlation ID: $CORRELATION_ID"
exit 0
