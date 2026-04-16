#!/bin/bash
# health.sh - Health check script for Open-ClaudeCode
# Returns JSON with health status
# Usage: ./health.sh [--json]

PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
OUTPUT_BASE="/Users/josh_folder/harness-pro-for-vibe/harness-blogs/progressive-scaffolding-workspace/v2-iteration-2/eval-1-v1_baseline/outputs"
PID_FILE="$OUTPUT_BASE/.harness/Open-ClaudeCode.pid"
CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "health-$(date +%s)")}"
TIMESTAMP=$(date -Iseconds)
FORMAT="${1:-}"

export CORRELATION_ID

# Build health status
STATUS="unknown"
PROCESS_RUNNING=false
PID_VALUE="null"

# Check process
if [ -f "$PID_FILE" ]; then
    PID_VALUE=$(cat "$PID_FILE")
    if ps -p "$PID_VALUE" > /dev/null 2>&1; then
        STATUS="running"
        PROCESS_RUNNING=true
    else
        STATUS="process_not_running"
    fi
else
    STATUS="not_started"
fi

# Check source files
SRC_FILES=$(find "$PROJECT_ROOT/src" -type f \( -name "*.ts" -o -name "*.tsx" \) 2>/dev/null | wc -l | tr -d ' ')
ENTRY_EXISTS="false"
if [ -f "$PROJECT_ROOT/src/main.tsx" ]; then
    ENTRY_EXISTS="true"
fi

# Check telemetry infrastructure
TELEMETRY_FILES=$(find "$PROJECT_ROOT/src" -type f \( -name "*telemetry*" -o -name "*analytics*" \) 2>/dev/null | wc -l | tr -d ' ')

# Output
if [ "$FORMAT" = "--json" ] || [ "$FORMAT" = "-j" ]; then
    cat << EOF
{
  "status": "$STATUS",
  "timestamp": "$TIMESTAMP",
  "correlation_id": "$CORRELATION_ID",
  "process": {
    "pid_file": "$PID_FILE",
    "pid": $PID_VALUE,
    "running": $PROCESS_RUNNING
  },
  "source": {
    "typescript_files": $SRC_FILES,
    "entry_point_exists": $ENTRY_EXISTS,
    "entry_point": "$PROJECT_ROOT/src/main.tsx"
  },
  "observability": {
    "telemetry_files": $TELEMETRY_FILES,
    "telemetry_path": "src/utils/telemetry/, src/services/analytics/"
  }
}
EOF
else
    echo "[$CORRELATION_ID] === Open-ClaudeCode Health Check ==="
    echo "Status:      $STATUS"
    echo "PID:         $PID_VALUE"
    echo "Source files: $SRC_FILES TypeScript files"
    echo "Entry point: $ENTRY_EXISTS ($PROJECT_ROOT/src/main.tsx)"
    echo "Telemetry:   $TELEMETRY_FILES telemetry/analytics files"
    echo "Timestamp:   $TIMESTAMP"
fi

# Exit code: 0 if running or not-started is OK; 1 if process_not_running
if [ "$STATUS" = "process_not_running" ]; then
    exit 1
fi
exit 0
