#!/bin/bash
# start.sh - Start the service
# Customize this script based on your project's start mechanism

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.harness/observability/logs"
PID_FILE="$PROJECT_ROOT/.harness/open_claude_code.pid"

mkdir -p "$LOG_DIR"

# Generate correlation ID for this run
CORRELATION_ID="$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "run-$(date +%s)")"
export CORRELATION_ID

echo "[$CORRELATION_ID] Starting open_claude_code..."

# Detect how to start based on project files
if [ -f "$PROJECT_ROOT/package.json" ]; then
    cd "$PROJECT_ROOT"
    npm start > "$LOG_DIR/open_claude_code-$(date +%Y%m%d-%H%M%S).log" 2>&1 &
    echo $! > "$PID_FILE"
    echo "Started with npm (PID: $(cat $PID_FILE))"
elif [ -f "$PROJECT_ROOT/go.mod" ]; then
    cd "$PROJECT_ROOT"
    go run ./cmd/server > "$LOG_DIR/open_claude_code-$(date +%Y%m%d-%H%M%S).log" 2>&1 &
    echo $! > "$PID_FILE"
    echo "Started with go run (PID: $(cat $PID_FILE))"
elif [ -f "$PROJECT_ROOT/Makefile" ]; then
    cd "$PROJECT_ROOT"
    make run > "$LOG_DIR/open_claude_code-$(date +%Y%m%d-%H%M%S).log" 2>&1 &
    echo $! > "$PID_FILE"
    echo "Started with make run (PID: $(cat $PID_FILE))"
else
    echo "Error: Cannot detect how to start project"
    echo "Please customize start.sh for your project"
    exit 1
fi

echo "[$CORRELATION_ID] Started with correlation ID"
echo "Logs: $LOG_DIR"
