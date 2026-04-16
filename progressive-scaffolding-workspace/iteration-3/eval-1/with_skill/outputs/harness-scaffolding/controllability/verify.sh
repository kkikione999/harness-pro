#!/bin/bash
# verify.sh - Verify project structure and lint health
# Returns: 0 if healthy, non-zero if unhealthy
# For a CLI project, "healthy" means: structure intact + lint checks pass.

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CHECK_SCRIPT="$PROJECT_ROOT/rules/scripts/check.py"
ERRORS=0

echo "=== Project Verification ==="
echo ""

# Structural checks
echo "Checking project structure..."

if [ -d "$PROJECT_ROOT/src" ]; then
    echo "  [OK] src/ directory exists"
else
    echo "  [FAIL] src/ directory missing"
    ERRORS=$((ERRORS + 1))
fi

if [ -d "$PROJECT_ROOT/src/tools" ]; then
    TOOL_COUNT=$(find "$PROJECT_ROOT/src/tools" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
    echo "  [OK] src/tools/ exists ($TOOL_COUNT files)"
else
    echo "  [FAIL] src/tools/ missing"
    ERRORS=$((ERRORS + 1))
fi

if [ -d "$PROJECT_ROOT/src/commands" ]; then
    CMD_COUNT=$(find "$PROJECT_ROOT/src/commands" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
    echo "  [OK] src/commands/ exists ($CMD_COUNT files)"
else
    echo "  [FAIL] src/commands/ missing"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$PROJECT_ROOT/package/package.json" ]; then
    echo "  [OK] package/package.json exists"
else
    echo "  [FAIL] package/package.json missing"
    ERRORS=$((ERRORS + 1))
fi

if [ -f "$CHECK_SCRIPT" ]; then
    LINT_COUNT=$(ls "$PROJECT_ROOT/rules/scripts"/lint-*.sh 2>/dev/null | wc -l | tr -d ' ')
    echo "  [OK] rules/scripts/check.py exists ($LINT_COUNT lint scripts)"
else
    echo "  [FAIL] rules/scripts/check.py missing"
    ERRORS=$((ERRORS + 1))
fi

echo ""

# Lint checks (if check.py is available)
if [ -f "$CHECK_SCRIPT" ]; then
    echo "Running lint verification..."
    if python3 "$CHECK_SCRIPT" 2>&1; then
        echo ""
        echo "VERIFICATION PASSED: All Golden Principle checks passed"
    else
        echo ""
        echo "VERIFICATION FAILED: Some lint checks failed"
        ERRORS=$((ERRORS + 1))
    fi
else
    echo "WARNING: check.py not found, skipping lint verification"
fi

exit $ERRORS
