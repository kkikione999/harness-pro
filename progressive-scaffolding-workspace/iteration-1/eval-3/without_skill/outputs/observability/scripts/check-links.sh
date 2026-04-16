#!/bin/bash
# Link checking script for harness-blogs documentation

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Link Checker ==="
echo ""

link_issues=0

echo "--- Checking Internal Links ---"
for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")

        # Check for relative links to other markdown files
        relative_md_links=$(grep -oE '\[([^\]]+)\]\(\.\/([^)]+\.md)\)' "$f" 2>/dev/null || true)

        # Check for links to non-existent files
        while IFS= read -r link; do
            if [ -n "$link" ]; then
                # Extract the target file
                target=$(echo "$link" | sed -E 's/.*\(\.\/(.*)\).*/\1/')
                if [ -n "$target" ] && [ ! -f "$PROJECT_ROOT/$target" ]; then
                    echo "  WARNING: $filename links to missing file: $target"
                    link_issues=$((link_issues + 1))
                fi
            fi
        done <<< "$relative_md_links"
    fi
done

echo ""
echo "--- Checking Anchor Links ---"
for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")

        # Check for anchor links
        anchor_links=$(grep -oE '\[([^\]]+)\]\(#([^)]+)\)' "$f" 2>/dev/null || true)

        if [ -n "$anchor_links" ]; then
            anchor_count=$(echo "$anchor_links" | wc -l)
            echo "  INFO: $filename has $anchor_count anchor link(s)"
        fi
    fi
done

echo ""
echo "--- Link Summary ---"
echo "Link issues found: $link_issues"
if [ "$link_issues" -eq 0 ]; then
    echo "Status: PASS"
else
    echo "Status: ISSUES FOUND"
fi

echo ""
echo "=== Link Checker Complete ==="