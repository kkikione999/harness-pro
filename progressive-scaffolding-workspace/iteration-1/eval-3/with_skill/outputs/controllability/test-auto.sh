#!/bin/bash
# test-auto.sh - Automated test script for harness-blogs
# Outputs structured JSON results for parsing

set -e

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HARNESS_DIR/.." && pwd)"

CORRELATION_ID="test-$$-$(date +%Y%m%d-%H%M%S)"
TEST_START=$(date +%s)

echo "=== harness-blogs Automated Tests ==="
echo "Correlation ID: $CORRELATION_ID"
echo "Start time: $(date -Iseconds)"
echo ""

# Test results array
declare -a TEST_RESULTS
PASS_COUNT=0
FAIL_COUNT=0

# Helper function to record test result
record_test() {
    local name="$1"
    local status="$2"
    local message="$3"

    if [ "$status" = "PASS" ]; then
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi

    TEST_RESULTS+=("{\"name\": \"$name\", \"status\": \"$status\", \"message\": \"$message\"}")
}

# Test 1: Project structure
echo "[1/4] Testing project structure..."
if [ -d "$PROJECT_ROOT" ] && [ -f "$PROJECT_ROOT/HARNESS-ENGINEERING-IMPLEMENTATION-GUIDE.md" ]; then
    record_test "project_structure" "PASS" "All required files present"
    echo "  ✓ PASS"
else
    record_test "project_structure" "FAIL" "Missing project files"
    echo "  ✗ FAIL"
fi

# Test 2: Markdown validity (basic check for frontmatter)
echo "[2/4] Testing markdown validity..."
VALID_MD=true
for md in "$PROJECT_ROOT"/*.md; do
    if [ -f "$md" ]; then
        # Basic check: file should not be empty
        if [ ! -s "$md" ]; then
            VALID_MD=false
            record_test "markdown_validity" "FAIL" "Empty markdown file: $md"
            echo "  ✗ FAIL: Empty file $md"
        fi
    fi
done
if [ "$VALID_MD" = true ]; then
    record_test "markdown_validity" "PASS" "All markdown files valid"
    echo "  ✓ PASS"
fi

# Test 3: Documentation completeness
echo "[3/4] Testing documentation completeness..."
DOC_FILES=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$DOC_FILES" -ge 10 ]; then
    record_test "doc_completeness" "PASS" "Found $DOC_FILES documentation files"
    echo "  ✓ PASS: $DOC_FILES files"
else
    record_test "doc_completeness" "FAIL" "Only $DOC_FILES files found, expected >=10"
    echo "  ✗ FAIL: Only $DOC_FILES files"
fi

# Test 4: Links integrity (check for common broken patterns)
echo "[4/4] Testing link integrity..."
BROKEN_LINKS=0
for md in "$PROJECT_ROOT"/*.md; do
    if [ -f "$md" ]; then
        # Check for potential broken link patterns
        if grep -q '\]\[.*\]' "$md" 2>/dev/null; then
            # Potentially broken reference-style link
            BROKEN_LINKS=$((BROKEN_LINKS + 1))
        fi
    fi
done
if [ "$BROKEN_LINKS" -eq 0 ]; then
    record_test "link_integrity" "PASS" "No obvious broken links detected"
    echo "  ✓ PASS"
else
    record_test "link_integrity" "WARN" "Found $BROKEN_LINKS potential issues"
    echo "  ⚠ WARN: $BROKEN_LINKS potential issues"
fi

# Calculate duration
TEST_END=$(date +%s)
DURATION=$((TEST_END - TEST_START))

# Output structured results
echo ""
echo "=== Test Results Summary ==="
echo "Duration: ${DURATION}s"
echo "Passed: $PASS_COUNT"
echo "Failed: $FAIL_COUNT"
echo ""

# JSON output for machine parsing
echo "=== STRUCTURED OUTPUT ==="
printf '%s\n' '{"correlation_id": "'$CORRELATION_ID'", "timestamp": "'$(date -Iseconds)'", "duration": '$DURATION', "passed": '$PASS_COUNT', "failed": '$FAIL_COUNT', "tests": ['
FIRST=true
for result in "${TEST_RESULTS[@]}"; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        printf ','
    fi
    printf '%s' "$result"
done
printf '\n]}'

# Exit code
if [ $FAIL_COUNT -gt 0 ]; then
    exit 1
fi
exit 0
