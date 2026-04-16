#!/bin/bash
# Documentation linting script for harness-blogs

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Documentation Linter ==="
echo ""

lint_warnings=0

echo "--- Linting Markdown Files ---"
for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")
        file_warnings=0

        # Check for TODO comments
        todos=$(grep -c -i 'TODO' "$f" || true)
        if [ "$todos" -gt 0 ]; then
            echo "  INFO: $filename has $todos TODO comment(s)"
        fi

        # Check for FIXME comments
        fixes=$(grep -c -i 'FIXME' "$f" || true)
        if [ "$fixes" -gt 0 ]; then
            echo "  WARNING: $filename has $fixes FIXME comment(s)"
            file_warnings=$((file_warnings + fixes))
        fi

        # Check for hardcoded paths
        hardcoded_paths=$(grep -cE '^[^#]*\/[a-zA-Z0-9_/.-]+' "$f" 2>/dev/null || true)

        # Check for inconsistent header styles
        atx_headers=$(grep -cE '^#{1,6}\s' "$f" || true)
        setext_headers=$(grep -cE '^={3,}$|^-{3,}$' "$f" || true)

        if [ "$file_warnings" -eq 0 ]; then
            echo "  OK: $filename ($atx_headers headers)"
        else
            lint_warnings=$((lint_warnings + file_warnings))
        fi
    fi
done

echo ""
echo "--- Lint Summary ---"
echo "Total warnings: $lint_warnings"
if [ "$lint_warnings" -eq 0 ]; then
    echo "Status: PASS"
else
    echo "Status: WARNINGS FOUND"
fi

echo ""
echo "=== Documentation Linter Complete ==="