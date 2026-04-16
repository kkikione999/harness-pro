#!/bin/bash
# Test script for harness-blogs

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Test Suite ==="
echo ""

test_count=0
passed=0
failed=0

run_test() {
    test_name="$1"
    test_command="$2"
    test_count=$((test_count + 1))

    echo "Test $test_count: $test_name"
    if eval "$test_command"; then
        echo "  PASS"
        passed=$((passed + 1))
    else
        echo "  FAIL"
        failed=$((failed + 1))
    fi
    echo ""
}

# Test: Verify markdown files are readable
run_test "Markdown files are readable" "[ -r '$PROJECT_ROOT/01_anthropic_harness-design-long-running-apps.md' ]"

# Test: Verify markdown files have content
run_test "Markdown files have content" "[ -s '$PROJECT_ROOT/HARNESS-ENGINEERING-IMPLEMENTATION-GUIDE.md' ]"

# Test: Verify required directories exist
run_test "Required directories exist" "[ -d '$PROJECT_ROOT/.claude' ] && [ -d '$PROJECT_ROOT/.harness' ]"

# Test: Verify progressive-scaffolding-workspace structure
run_test "Workspace structure exists" "[ -d '$PROJECT_ROOT/progressive-scaffolding-workspace/iteration-1/eval-3' ]"

# Test: Check markdown syntax (basic)
run_test "Markdown files start with headers" "head -1 '$PROJECT_ROOT/01_anthropic_harness-design-long-running-apps.md' | grep -q '^#'"

# Test: Verify no empty markdown files
run_test "No empty markdown files" "[ \$(wc -l < '$PROJECT_ROOT/PROGRESSIVE-RULES-DESIGN.md') -gt 0 ]"

echo "=== Test Summary ==="
echo "Total tests: $test_count"
echo "Passed: $passed"
echo "Failed: $failed"
echo ""

if [ "$failed" -eq 0 ]; then
    echo "Status: ALL TESTS PASSED"
    exit 0
else
    echo "Status: SOME TESTS FAILED"
    exit 1
fi