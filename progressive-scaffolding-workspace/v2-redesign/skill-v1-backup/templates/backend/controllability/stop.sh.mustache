#!/bin/bash
# stop.sh - Stop the service

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PID_FILE="$PROJECT_ROOT/.harness/{{project-name}}.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    echo "Stopping PID $PID..."
    kill "$PID" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "Stopped"
else
    echo "No PID file found, attempting to stop any running instance..."
    pkill -f "{{project-name}}" 2>/dev/null || true
    echo "Done"
fi
