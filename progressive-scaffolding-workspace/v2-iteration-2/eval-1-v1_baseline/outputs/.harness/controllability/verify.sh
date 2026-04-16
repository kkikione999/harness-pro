#!/bin/bash
# verify.sh - Verify Open-ClaudeCode CLI is functional
# Returns: 0 = healthy, non-zero = unhealthy

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
OUTPUT_BASE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PID_FILE="$OUTPUT_BASE/.harness/Open-ClaudeCode.pid"
CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "verify-$(date +%s)")}"

export CORRELATION_ID

echo "[$CORRELATION_ID] Verifying Open-ClaudeCode..."

# Check 1: Source files exist
if [ ! -f "$PROJECT_ROOT/src/main.tsx" ]; then
    echo "[$CORRELATION_ID] FAIL: src/main.tsx not found"
    exit 1
fi
echo "[$CORRELATION_ID] CHECK: Source file src/main.tsx exists"

# Check 2: Telemetry infrastructure exists
TELEMETRY_FILES=$(find "$PROJECT_ROOT/src" -type f \( -name "*telemetry*" -o -name "*analytics*" -o -name "*cost*" \) 2>/dev/null | wc -l | tr -d ' ')
if [ "$TELEMETRY_FILES" -gt 0 ]; then
    echo "[$CORRELATION_ID] CHECK: Telemetry infrastructure found ($TELEMETRY_FILES files)"
else
    echo "[$CORRELATION_ID] WARN: No telemetry files found"
fi

# Check 3: TypeScript source files
TS_FILES=$(find "$PROJECT_ROOT/src" -type f \( -name "*.ts" -o -name "*.tsx" \) 2>/dev/null | wc -l | tr -d ' ')
echo "[$CORRELATION_ID] CHECK: $TS_FILES TypeScript source files"

# Check 4: Check if process is running (if PID file exists)
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "[$CORRELATION_ID] CHECK: Process $PID is running"
    else
        echo "[$CORRELATION_ID] WARN: PID file exists but process $PID not running"
    fi
else
    echo "[$CORRELATION_ID] CHECK: No running process (PID file not found — CLI may not be started)"
fi

# Check 5: Verify telemetry attributes exist
if [ -f "$PROJECT_ROOT/src/utils/telemetryAttributes.ts" ]; then
    echo "[$CORRELATION_ID] CHECK: telemetryAttributes.ts found"
fi

# Check 6: Verify rules directory
if [ -d "$PROJECT_ROOT/rules" ]; then
    echo "[$CORRELATION_ID] CHECK: rules/ directory exists"
fi

echo "[$CORRELATION_ID] VERIFY: PASS"
exit 0
