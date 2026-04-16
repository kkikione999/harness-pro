#!/bin/bash
# start.sh - Start the Open-ClaudeCode CLI for testing
# This launches the CLI binary in a way an agent can control.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.harness/observability/logs"
PID_FILE="$PROJECT_ROOT/.harness/Open_ClaudeCode.pid"

mkdir -p "$LOG_DIR"

# Generate correlation ID for this run
CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || python3 -c 'import uuid; print(uuid.uuid4())' 2>/dev/null || echo "run-$(date +%s)")"
export CORRELATION_ID

echo "[$CORRELATION_ID] Starting Open-ClaudeCode CLI..."

# The CLI binary is at package/cli.js
CLI_PATH="$PROJECT_ROOT/package/cli.js"

if [ -f "$CLI_PATH" ]; then
    cd "$PROJECT_ROOT"
    node "$CLI_PATH" "$@" > "$LOG_DIR/cli-run-$(date +%Y%m%d-%H%M%S).log" 2>&1 &
    echo $! > "$PID_FILE"
    echo "[$CORRELATION_ID] Started CLI (PID: $(cat $PID_FILE))"
    echo "Logs: $LOG_DIR"
else
    echo "Error: CLI not found at $CLI_PATH"
    echo "This is a read-only source project; CLI execution may not be available."
    exit 1
fi
