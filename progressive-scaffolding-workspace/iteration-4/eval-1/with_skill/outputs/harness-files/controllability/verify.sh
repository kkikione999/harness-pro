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

# --- Structural checks ---
echo "Checking project structure..."

check_dir() {
    local dir="$PROJECT_ROOT/$1"
    local label="$2"
    if [ -d "$dir" ]; then
        local count
        count=$(find "$dir" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
        echo "  [OK] $label exists ($count files)"
    else
        echo "  [FAIL] $label missing"
        ERRORS=$((ERRORS + 1))
    fi
}

check_file() {
    local file="$PROJECT_ROOT/$1"
    local label="$2"
    if [ -f "$file" ]; then
        echo "  [OK] $label exists"
    else
        echo "  [FAIL] $label missing"
        ERRORS=$((ERRORS + 1))
    fi
}

check_dir "src" "src/"
check_dir "src/tools" "src/tools/"
check_dir "src/commands" "src/commands/"
check_dir "src/hooks" "src/hooks/"
check_dir "src/components" "src/components/"
check_dir "src/services" "src/services/"
check_file "package/package.json" "package/package.json"
check_file "rules/scripts/check.py" "rules/scripts/check.py"

# Check lint scripts count
LINT_COUNT=$(ls "$PROJECT_ROOT/rules/scripts"/lint-*.sh 2>/dev/null | wc -l | tr -d ' ')
if [ "$LINT_COUNT" -gt 0 ]; then
    echo "  [OK] lint scripts found ($LINT_COUNT scripts)"
else
    echo "  [FAIL] no lint scripts found"
    ERRORS=$((ERRORS + 1))
fi

# Check rules registry
check_file "rules/_registry.json" "rules/_registry.json"

echo ""

# --- Lint checks ---
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

echo ""
if [ "$ERRORS" -eq 0 ]; then
    echo "Result: HEALTHY (0 errors)"
else
    echo "Result: UNHEALTHY ($ERRORS error(s))"
fi

exit "$ERRORS"
