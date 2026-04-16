#!/bin/bash
# controllability/test-auto.sh - Automated test runner for progressive-scaffolding skill

set -e

SKILL_ROOT="${PROJECT_ROOT:-.}"

echo "=== Automated Test Runner ==="
echo ""

# Track results
TOTAL=0
PASSED=0
FAILED=0

# Test function
run-test() {
    local name="$1"
    local cmd="$2"

    TOTAL=$((TOTAL + 1))
    echo -n "Test $TOTAL: $name ... "

    if eval "$cmd" > /dev/null 2>&1; then
        echo "PASS"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo "FAIL"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# Run probe tests
echo "Running probe tests..."
run-test "detect-project-type" "bash $SKILL_ROOT/scripts/detect-project-type.sh $SKILL_ROOT"
run-test "detect-controllability" "bash $SKILL_ROOT/scripts/detect-controllability.sh $SKILL_ROOT"
run-test "detect-observability" "bash $SKILL_ROOT/scripts/detect-observability.sh $SKILL_ROOT"
run-test "detect-verification" "bash $SKILL_ROOT/scripts/detect-verification.sh $SKILL_ROOT"

# Run scaffolding tests
echo ""
echo "Running scaffolding tests..."
run-test "generate-scaffolding" "bash $SKILL_ROOT/scripts/generate-scaffolding.sh /tmp/test-project-$$ --type backend --force"

# Run observability tests
echo ""
echo "Running observability tests..."
run-test "health-check" "bash .harness/observability/health.sh check"
run-test "log-script" "bash .harness/observability/log.sh recent"
run-test "trace-script" "bash .harness/observability/trace.sh get"

# Summary
echo ""
echo "=== Test Summary ==="
echo "Total: $TOTAL"
echo "Passed: $PASSED"
echo "Failed: $FAILED"

# Output structured result
echo ""
echo "Structured Result:"
echo "{\"total\":$TOTAL,\"passed\":$PASSED,\"failed\":$FAILED,\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"

# Exit with appropriate code
if [ $FAILED -eq 0 ]; then
    echo "Status: ALL TESTS PASSED"
    exit 0
else
    echo "Status: SOME TESTS FAILED"
    exit 1
fi