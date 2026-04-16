#!/bin/bash
# test-auto.sh - Automated test with structured output
# Returns exit code: 0 = all pass, 1 = any failure

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "=== Automated Test Run ==="
echo "Timestamp: $(date -Iseconds)"
echo ""

# Detect test framework
TEST_RESULT="{}"

if [ -f "package.json" ] && grep -q '"test"' package.json; then
    echo "Running npm test..."
    if npm test 2>&1 | tee /tmp/test-output.txt; then
        TEST_RESULT='{"status":"pass","framework":"npm","timestamp":"'$(date -Iseconds)'"}'
        echo ""
        echo "✓ Tests passed"
        exit 0
    else
        TEST_RESULT='{"status":"fail","framework":"npm","timestamp":"'$(date -Iseconds)'"}'
        echo ""
        echo "✗ Tests failed"
        exit 1
    fi
elif [ -f "go.mod" ]; then
    echo "Running go test..."
    if go test -v ./... 2>&1 | tee /tmp/test-output.txt; then
        TEST_RESULT='{"status":"pass","framework":"go","timestamp":"'$(date -Iseconds)'"}'
        echo ""
        echo "✓ Tests passed"
        exit 0
    else
        TEST_RESULT='{"status":"fail","framework":"go","timestamp":"'$(date -Iseconds)'"}'
        echo ""
        echo "✗ Tests failed"
        exit 1
    fi
elif [ -f "Makefile" ] && grep -q "test" Makefile; then
    echo "Running make test..."
    if make test 2>&1 | tee /tmp/test-output.txt; then
        TEST_RESULT='{"status":"pass","framework":"make","timestamp":"'$(date -Iseconds)'"}'
        echo ""
        echo "✓ Tests passed"
        exit 0
    else
        TEST_RESULT='{"status":"fail","framework":"make","timestamp":"'$(date -Iseconds)'"}'
        echo ""
        echo "✗ Tests failed"
        exit 1
    fi
else
    echo "No test framework detected"
    echo "Please customize test-auto.sh for your project"
    exit 1
fi
