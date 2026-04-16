#!/bin/bash
# Documentation health check script for harness-blogs

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Documentation Health ==="
echo ""

health_score=100
issues=0

echo "--- Checking Markdown Files ---"
for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")
        errors=0

        # Check for trailing whitespace
        trailing=$(grep -l ' $' "$f" 2>/dev/null || true)
        if [ -n "$trailing" ]; then
            echo "  WARNING: $filename has trailing whitespace"
            errors=$((errors + 1))
        fi

        # Check for very long lines (over 200 characters)
        long_lines=$(awk 'length > 200' "$f" | wc -l)
        if [ "$long_lines" -gt 0 ]; then
            echo "  WARNING: $filename has $long_lines lines over 200 characters"
            errors=$((errors + long_lines))
        fi

        # Check for missing frontmatter (if applicable)
        if head -1 "$f" | grep -q "^---$"; then
            echo "  INFO: $filename has frontmatter"
        fi

        if [ "$errors" -eq 0 ]; then
            echo "  OK: $filename"
        else
            issues=$((issues + errors))
        fi
    fi
done

echo ""
echo "--- Checking File Structure ---"
# Check for required directories
required_dirs=("progressive-scaffolding-workspace")
for dir in "${required_dirs[@]}"; do
    if [ -d "$PROJECT_ROOT/$dir" ]; then
        echo "  OK: $dir/ exists"
    else
        echo "  WARNING: $dir/ is missing"
        issues=$((issues + 1))
    fi
done

echo ""
echo "--- Health Summary ---"
echo "Issues found: $issues"
if [ "$issues" -eq 0 ]; then
    echo "Health Score: 100/100"
    echo "Status: HEALTHY"
else
    health_score=$((100 - issues))
    echo "Health Score: $health_score/100"
    echo "Status: NEEDS ATTENTION"
fi

echo ""
echo "=== Documentation Health Check Complete ==="