#!/bin/bash
# start.sh - Start Open-ClaudeCode CLI
# Usage: ./start.sh [--args "..."]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
OUTPUT_BASE="$(cd "$SCRIPT_DIR/../../.." && pwd)"  # outputs/
LOG_DIR="$OUTPUT_BASE/.harness/observability/logs"
PID_FILE="$OUTPUT_BASE/.harness/Open-ClaudeCode.pid"
CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "run-$(date +%s)")}"

# Optional CLI args
CLI_ARGS="${1:-}"

mkdir -p "$LOG_DIR"

export CORRELATION_ID

echo "[$CORRELATION_ID] Starting Open-ClaudeCode..."
echo "[$CORRELATION_ID] Project root: $PROJECT_ROOT"

# Detect how to start
if command -v tsx >/dev/null 2>&1; then
    START_CMD="tsx src/main.tsx"
    RUNNER="tsx"
elif command -v bun >/dev/null 2>&1; then
    START_CMD="bun run src/main.tsx"
    RUNNER="bun"
elif command -v npx >/dev/null 2>&1; then
    START_CMD="npx tsx src/main.tsx"
    RUNNER="npx tsx"
elif [ -f "$PROJECT_ROOT/package/cli.js" ]; then
    START_CMD="./package/cli.js"
    RUNNER="node"
else
    echo "[$CORRELATION_ID] ERROR: No TypeScript runtime found (tsx, bun, npx) and no CLI bundle."
    echo "[$CORRELATION_ID] Please install tsx: npm install -g tsx"
    exit 1
fi

LOG_FILE="$LOG_DIR/Open-ClaudeCode-$(date +%Y%m%d-%H%M%S).log"

cd "$PROJECT_ROOT"
echo "[$CORRELATION_ID] Starting with $RUNNER: $START_CMD $CLI_ARGS"
echo "[$CORRELATION_ID] Log file: $LOG_FILE"

# Start in background
$START_CMD $CLI_ARGS >> "$LOG_FILE" 2>&1 &
PID=$!
echo $PID > "$PID_FILE"

echo "[$CORRELATION_ID] Started PID $PID with correlation ID $CORRELATION_ID"
echo "[$CORRELATION_ID] Logs: $LOG_DIR"
echo "PID_FILE=$PID_FILE"
