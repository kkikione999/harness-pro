#!/bin/bash
# test-auto.sh - Automated test with structured output and log capture
# Wraps check.py to produce machine-readable JSON results alongside human output.
# Returns: 0 = all pass, 1 = any failure, 2 = infrastructure error

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
    echo '{"status":"error","error":"check.py not found","correlation_id":"'"$CORRELATION_ID"'","timestamp":"'"$TIMESTAMP"'"}'
    exit 2
fi

# Run check.py, capture output to log file and stdout
# Use pipefail to propagate exit code from check.py through tee
cd "$PROJECT_ROOT"
set -o pipefail
LINT_EXIT=0
python3 "$CHECK_SCRIPT" 2>&1 | tee "$LOG_FILE" || LINT_EXIT=$?
set +o pipefail

echo ""

# Parse results from check.py summary line: "=== Summary: X passed, Y failed, Z skipped ==="
SUMMARY_LINE=$(grep "Summary:" "$LOG_FILE" 2>/dev/null | head -1)
PASS_COUNT=$(echo "$SUMMARY_LINE" | awk '{gsub(/[=:,]/,""); for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/ && $(i+1)=="passed") print $i}')
FAIL_COUNT=$(echo "$SUMMARY_LINE" | awk '{gsub(/[=:,]/,""); for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/ && $(i+1)=="failed") print $i}')
SKIP_COUNT=$(echo "$SUMMARY_LINE" | awk '{gsub(/[=:,]/,""); for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/ && $(i+1)=="skipped") print $i}')
PASS_COUNT=${PASS_COUNT:-0}
FAIL_COUNT=${FAIL_COUNT:-0}
SKIP_COUNT=${SKIP_COUNT:-0}

TIMESTAMP_END=$(date -Iseconds)

if [ "$LINT_EXIT" -eq 0 ]; then
    cat <<EOF
{"status":"pass","framework":"gp-lint","correlation_id":"$CORRELATION_ID","timestamp_start":"$TIMESTAMP","timestamp_end":"$TIMESTAMP_END","rules_passed":$PASS_COUNT,"rules_failed":0,"rules_skipped":$SKIP_COUNT,"log_file":"$LOG_FILE"}
EOF
    echo "RESULT: All Golden Principle checks passed"
    exit 0
else
    cat <<EOF
{"status":"fail","framework":"gp-lint","correlation_id":"$CORRELATION_ID","timestamp_start":"$TIMESTAMP","timestamp_end":"$TIMESTAMP_END","rules_passed":$PASS_COUNT,"rules_failed":$FAIL_COUNT,"rules_skipped":$SKIP_COUNT,"log_file":"$LOG_FILE"}
EOF
    echo "RESULT: Some checks failed ($FAIL_COUNT rule(s))"
    exit 1
fi
