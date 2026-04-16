#!/bin/bash
# stop.sh - Stop the Open-ClaudeCode CLI process

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_BASE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
PID_FILE="$OUTPUT_BASE/.harness/Open-ClaudeCode.pid"
CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "stop-$(date +%s)")}"

export CORRELATION_ID

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    echo "[$CORRELATION_ID] Stopping PID $PID..."
    if ps -p "$PID" > /dev/null 2>&1; then
        kill "$PID" 2>/dev/null || true
        sleep 1
        if ps -p "$PID" > /dev/null 2>&1; then
            kill -9 "$PID" 2>/dev/null || true
        fi
        echo "[$CORRELATION_ID] Process $PID stopped"
    else
        echo "[$CORRELATION_ID] Process $PID not running"
    fi
    rm -f "$PID_FILE"
else
    echo "[$CORRELATION_ID] No PID file found at $PID_FILE"
    echo "[$CORRELATION_ID] Attempting to stop any running Open-ClaudeCode process..."
    pkill -f "tsx.*main.tsx" 2>/dev/null || true
    pkill -f "bun.*main.tsx" 2>/dev/null || true
    pkill -f "node.*cli.js" 2>/dev/null || true
    echo "[$CORRELATION_ID] Done"
fi

echo "[$CORRELATION_ID] Stop complete"
