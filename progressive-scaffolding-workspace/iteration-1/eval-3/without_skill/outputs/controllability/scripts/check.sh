#!/bin/bash
# Comprehensive check script for harness-blogs

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Comprehensive Check ==="
echo ""
echo "Project root: $PROJECT_ROOT"
echo "Date: $(date)"
echo ""

checks_passed=0
checks_failed=0

check_pass() {
    echo "  [PASS] $1"
    checks_passed=$((checks_passed + 1))
}

check_fail() {
    echo "  [FAIL] $1"
    checks_failed=$((checks_failed + 1))
}

echo "--- File Structure Checks ---"
if [ -d "$PROJECT_ROOT" ]; then
    check_pass "Project root exists"
else
    check_fail "Project root missing"
fi

if [ -d "$PROJECT_ROOT/.claude" ]; then
    check_pass ".claude directory exists"
else
    check_fail ".claude directory missing"
fi

if [ -d "$PROJECT_ROOT/.harness" ]; then
    check_pass ".harness directory exists"
else
    check_fail ".harness directory missing"
fi

echo ""
echo "--- Documentation Checks ---"
md_count=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
if [ "$md_count" -gt 10 ]; then
    check_pass "Documentation files present ($md_count files)"
else
    check_fail "Insufficient documentation files ($md_count found)"
fi

# Check for key documentation files
key_files=(
    "HARNESS-ENGINEERING-IMPLEMENTATION-GUIDE.md"
    "PROGRESSIVE-RULES-DESIGN.md"
    "investigation-report-harness-philosophy.md"
)

for file in "${key_files[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        check_pass "$file exists"
    else
        check_fail "$file missing"
    fi
done

echo ""
echo "--- Workspace Checks ---"
if [ -d "$PROJECT_ROOT/progressive-scaffolding-workspace" ]; then
    check_pass "progressive-scaffolding-workspace exists"
else
    check_fail "progressive-scaffolding-workspace missing"
fi

if [ -d "$PROJECT_ROOT/progressive-rules-workspace" ]; then
    check_pass "progressive-rules-workspace exists"
else
    check_fail "progressive-rules-workspace missing"
fi

echo ""
echo "--- Content Quality Checks ---"
# Check that key files have reasonable content
main_guide="$PROJECT_ROOT/HARNESS-ENGINEERING-IMPLEMENTATION-GUIDE.md"
if [ -f "$main_guide" ]; then
    lines=$(wc -l < "$main_guide")
    if [ "$lines" -gt 100 ]; then
        check_pass "Main implementation guide has substantial content ($lines lines)"
    else
        check_fail "Main implementation guide seems too short ($lines lines)"
    fi
fi

echo ""
echo "=== Check Summary ==="
echo "Passed: $checks_passed"
echo "Failed: $checks_failed"
echo ""

if [ "$checks_failed" -eq 0 ]; then
    echo "Status: ALL CHECKS PASSED"
    exit 0
else
    echo "Status: SOME CHECKS FAILED"
    exit 1
fi