#!/bin/bash
# test-auto.sh - Automated test with structured output and log capture
# Wraps check.py to produce machine-readable results.
# Returns: 0 = all pass, 1 = any failure

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.harness/observability/logs"
CHECK_SCRIPT="$PROJECT_ROOT/rules/scripts/check.py"

mkdir -p "$LOG_DIR"

CORRELATION_ID="${CORRELATION_ID:-auto-$(date +%s)}"
TIMESTAMP=$(date -Iseconds)
LOG_FILE="$LOG_DIR/test-auto-$(date +%Y%m%d-%H%M%S).log"

echo "=== Automated Test Run ==="
echo "Timestamp: $TIMESTAMP"
echo "Correlation ID: $CORRELATION_ID"
echo ""

if [ ! -f "$CHECK_SCRIPT" ]; then
    echo '{"status":"error","error":"check.py not found","timestamp":"'"$TIMESTAMP"'"}'
    exit 1
fi

# Run check.py and capture output
cd "$PROJECT_ROOT"
if python3 "$CHECK_SCRIPT" 2>&1 | tee "$LOG_FILE"; then
    echo ""
    echo '{"status":"pass","framework":"gp-lint","correlation_id":"'"$CORRELATION_ID"'","timestamp":"'"$TIMESTAMP"'","log_file":"'"$LOG_FILE"'"}'
    echo "RESULT: All Golden Principle checks passed"
    exit 0
else
    echo ""
    echo '{"status":"fail","framework":"gp-lint","correlation_id":"'"$CORRELATION_ID"'","timestamp":"'"$TIMESTAMP"'","log_file":"'"$LOG_FILE"'"}'
    echo "RESULT: Some checks failed"
    exit 1
fi
