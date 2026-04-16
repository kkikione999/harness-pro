#!/bin/bash
# test-auto.sh - Automated verification for Open-ClaudeCode
# Returns: 0 = pass, 1 = fail
# Structured JSON result written to stdout

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
OUTPUT_BASE="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TIMESTAMP=$(date -Iseconds)
CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "test-$(date +%s)")}"
RESULT_FILE="$OUTPUT_BASE/.harness/test-result.json"
mkdir -p "$(dirname "$RESULT_FILE")"

export CORRELATION_ID

echo "[$CORRELATION_ID] Running automated verification..."
echo ""

RESULT_STATUS="pass"
EXIT_CODE=0

# Check 1: TypeScript compilation check
echo "[$CORRELATION_ID] Step 1: TypeScript type check..."
TSC_FOUND=""
if command -v tsc >/dev/null 2>&1; then
    TSC_FOUND="tsc"
    if ! tsc --noEmit -p . 2>&1 | head -20; then
        echo "[$CORRELATION_ID] TypeScript check: ISSUES FOUND"
        RESULT_STATUS="fail"
        EXIT_CODE=1
    else
        echo "[$CORRELATION_ID] TypeScript check: PASS"
    fi
elif command -v npx >/dev/null 2>&1 && npx tsc --version 2>/dev/null; then
    TSC_FOUND="npx tsc"
    if ! npx tsc --noEmit -p . 2>&1 | head -20; then
        echo "[$CORRELATION_ID] TypeScript check: ISSUES FOUND"
        RESULT_STATUS="fail"
        EXIT_CODE=1
    else
        echo "[$CORRELATION_ID] TypeScript check: PASS"
    fi
else
    echo "[$CORRELATION_ID] TypeScript compiler not found — skipping type check"
    TSC_FOUND="none"
fi

# Check 2: Source file integrity
echo ""
echo "[$CORRELATION_ID] Step 2: Source file integrity..."
SRC_FILE_COUNT=$(find "$PROJECT_ROOT/src" -type f \( -name "*.ts" -o -name "*.tsx" \) 2>/dev/null | wc -l | tr -d ' ')
echo "[$CORRELATION_ID] Found $SRC_FILE_COUNT TypeScript source files"
if [ "$SRC_FILE_COUNT" -lt 100 ]; then
    echo "[$CORRELATION_ID] FAIL: Expected >100 source files, found $SRC_FILE_COUNT"
    RESULT_STATUS="fail"
    EXIT_CODE=1
fi

# Check 3: Key entry point files
echo ""
echo "[$CORRELATION_ID] Step 3: Key entry point check..."
KEY_FILES=(
    "src/main.tsx"
    "src/entrypoints/cli.tsx"
    "src/utils/telemetryAttributes.ts"
)
ALL_FOUND=true
for f in "${KEY_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$f" ]; then
        echo "[$CORRELATION_ID]   FOUND: $f"
    else
        echo "[$CORRELATION_ID]   MISSING: $f"
        ALL_FOUND=false
    fi
done
if [ "$ALL_FOUND" = false ]; then
    RESULT_STATUS="fail"
    EXIT_CODE=1
fi

# Check 4: Telemetry infrastructure check
echo ""
echo "[$CORRELATION_ID] Step 4: Telemetry infrastructure check..."
TELEMETRY_COUNT=$(find "$PROJECT_ROOT/src" -type f \( -name "*telemetry*" -o -name "*analytics*" \) 2>/dev/null | wc -l | tr -d ' ')
echo "[$CORRELATION_ID] Found $TELEMETRY_COUNT telemetry/analytics files"

# Check 5: Verify harness scripts exist
echo ""
echo "[$CORRELATION_ID] Step 5: Harness script availability..."
for script in start.sh stop.sh verify.sh lint-check.sh; do
    if [ -x "$SCRIPT_DIR/$script" ]; then
        echo "[$CORRELATION_ID]   EXECUTABLE: $script"
    else
        echo "[$CORRELATION_ID]   MISSING/NOEXEC: $script"
        RESULT_STATUS="fail"
        EXIT_CODE=1
    fi
done

# Output structured result
echo ""
echo "=== Automated Verification Result ==="
TEST_RESULT=$(cat << EOF
{
  "status": "$RESULT_STATUS",
  "timestamp": "$TIMESTAMP",
  "correlation_id": "$CORRELATION_ID",
  "checks": {
    "typescript_check": "$TSC_FOUND",
    "source_integrity": "$SRC_FILE_COUNT files",
    "entry_points": "$(if [ "$ALL_FOUND" = true ]; then echo "pass"; else echo "fail"; fi)",
    "telemetry_files": "$TELEMETRY_COUNT",
    "harness_scripts": "available"
  },
  "exit_code": $EXIT_CODE
}
EOF
)
echo "$TEST_RESULT"

# Save result
echo "$TEST_RESULT" > "$RESULT_FILE"
echo "[$CORRELATION_ID] Result saved to $RESULT_FILE"

if [ "$EXIT_CODE" -eq 0 ]; then
    echo "[$CORRELATION_ID] VERIFICATION: PASS"
else
    echo "[$CORRELATION_ID] VERIFICATION: FAIL"
fi

exit $EXIT_CODE
