#!/bin/bash
# lint-check.sh - Lint source files for Open-ClaudeCode
# Returns: 0 = pass, non-zero = issues found

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "lint-$(date +%s)")}"

export CORRELATION_ID

echo "[$CORRELATION_ID] Running lint checks for Open-ClaudeCode..."
echo ""

ISSUES=0

# Check 1: TypeScript compilation (if tsc available)
echo "[$CORRELATION_ID] Check 1: TypeScript compilation..."
if command -v tsc >/dev/null 2>&1 || (command -v npx >/dev/null 2>&1 && npx tsc --version 2>/dev/null); then
    TSC_CMD="${TSC_CMD:-$(command -v tsc 2>/dev/null || echo 'npx tsc')}"
    if $TSC_CMD --noEmit 2>&1 | head -30; then
        echo "[$CORRELATION_ID]   tsc --noEmit: PASS"
    else
        echo "[$CORRELATION_ID]   tsc --noEmit: ISSUES FOUND"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo "[$CORRELATION_ID]   tsc not available — skipping"
fi

# Check 2: Forbidden patterns (secrets, debug code left in)
echo ""
echo "[$CORRELATION_ID] Check 2: Secret / debug pattern scan..."
FORBIDDEN=$(grep -r "console.log.*console\|process.env.*SECRET\|password.*=.*['\"]" \
    "$PROJECT_ROOT/src" \
    --include="*.ts" --include="*.tsx" \
    -l 2>/dev/null | wc -l | tr -d ' ')
if [ "$FORBIDDEN" -gt 0 ]; then
    echo "[$CORRELATION_ID]   WARN: $FORBIDDEN files may contain secrets or hardcoded passwords"
    grep -r "console.log.*console\|process.env.*SECRET\|password.*=.*['\"]" \
        "$PROJECT_ROOT/src" \
        --include="*.ts" --include="*.tsx" \
        -l 2>/dev/null | head -5 | while read -r f; do
        echo "[$CORRELATION_ID]   - $f"
    done
    ISSUES=$((ISSUES + 1))
else
    echo "[$CORRELATION_ID]   No obvious secret patterns found"
fi

# Check 3: Import direction (layer hierarchy)
echo ""
echo "[$CORRELATION_ID] Check 3: Import direction (layer hierarchy)..."
if [ -x "$SCRIPT_DIR/lint-import-direction.sh" ]; then
    if "$SCRIPT_DIR/lint-import-direction.sh" 2>&1 | head -30; then
        echo "[$CORRELATION_ID]   Import direction: PASS"
    else
        echo "[$CORRELATION_ID]   Import direction: VIOLATIONS FOUND"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo "[$CORRELATION_ID]   lint-import-direction.sh not available — skipping"
fi

# Check 4: Circular dependency analysis
echo ""
echo "[$CORRELATION_ID] Check 4: Circular dependency analysis..."
if [ -x "$SCRIPT_DIR/analyze-deps.sh" ]; then
    if "$SCRIPT_DIR/analyze-deps.sh" 2>&1 | head -30; then
        echo "[$CORRELATION_ID]   Dependency analysis: PASS"
    else
        echo "[$CORRELATION_ID]   Dependency analysis: CYCLES FOUND"
        ISSUES=$((ISSUES + 1))
    fi
else
    echo "[$CORRELATION_ID]   analyze-deps.sh not available — skipping"
fi

echo ""
echo "[$CORRELATION_ID] Lint complete: $ISSUES issue groups found"
if [ "$ISSUES" -gt 0 ]; then
    echo "[$CORRELATION_ID] LINT: WARN"
    exit 1
else
    echo "[$CORRELATION_ID] LINT: PASS"
    exit 0
fi
