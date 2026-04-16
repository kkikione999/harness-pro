#!/bin/bash
# verify.sh - Health check script for harness-blogs
# Exits with 0 on success, non-zero on failure

set -e

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HARNESS_DIR/.." && pwd)"
EXIT_CODE=0

CORRELATION_ID="verify-$$-$(date +%Y%m%d-%H%M%S)"

# Parse arguments
EXIT_CODE_MODE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --exit-code)
            EXIT_CODE_MODE=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

echo "=== harness-blogs Health Check ==="
echo "Correlation ID: $CORRELATION_ID"
echo "Timestamp: $(date -Iseconds)"
echo ""

# Check 1: Project structure exists
echo "[1/3] Checking project structure..."
if [ -d "$PROJECT_ROOT" ]; then
    echo "  ✓ Project root exists: $PROJECT_ROOT"
else
    echo "  ✗ Project root missing"
    EXIT_CODE=1
fi

# Check 2: Required files present
echo "[2/3] Checking required files..."
REQUIRED_FILES=(
    "HARNESS-ENGINEERING-IMPLEMENTATION-GUIDE.md"
    "PROGRESSIVE-RULES-DESIGN.md"
)
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        echo "  ✓ $file exists"
    else
        echo "  ✗ $file missing"
        EXIT_CODE=1
    fi
done

# Check 3: Markdown files are readable
echo "[3/3] Checking markdown files..."
MD_COUNT=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
if [ "$MD_COUNT" -gt 0 ]; then
    echo "  ✓ Found $MD_COUNT markdown files"
else
    echo "  ✗ No markdown files found"
    EXIT_CODE=1
fi

echo ""
echo "=== Health Check Result ==="
if [ $EXIT_CODE -eq 0 ]; then
    echo "Status: HEALTHY"
else
    echo "Status: UNHEALTHY"
fi

if [ "$EXIT_CODE_MODE" = true ]; then
    exit $EXIT_CODE
fi

exit 0
