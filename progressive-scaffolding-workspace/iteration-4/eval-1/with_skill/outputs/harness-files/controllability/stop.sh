#!/bin/bash
# stop.sh - Stop the Open-ClaudeCode CLI process

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PID_FILE="$PROJECT_ROOT/.harness/Open_ClaudeCode.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Stopping Open-ClaudeCode CLI (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
        sleep 1
        # Force kill if still running
        if ps -p "$PID" > /dev/null 2>&1; then
            kill -9 "$PID" 2>/dev/null || true
        fi
        echo "Stopped."
    else
        echo "CLI not running (PID $PID not found)."
    fi
    rm -f "$PID_FILE"
else
    echo "No PID file found. CLI may not be running."
fi
