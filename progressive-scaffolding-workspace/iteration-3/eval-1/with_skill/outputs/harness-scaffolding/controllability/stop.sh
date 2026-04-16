#!/bin/bash
# stop.sh - Stop the Open-ClaudeCode CLI process

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PID_FILE="$PROJECT_ROOT/.harness/Open_ClaudeCode.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    echo "Stopping PID $PID..."
    kill "$PID" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "Stopped"
else
    echo "No PID file found. Attempting to stop any running instance..."
    pkill -f "cli.js" 2>/dev/null || true
    echo "Done"
fi
