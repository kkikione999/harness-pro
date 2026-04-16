#!/bin/bash
# Markdown-specific health check for harness-blogs

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Markdown Health ==="
echo ""

echo "--- Markdown Syntax Checks ---"
for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")
        syntax_errors=0

        # Check for unclosed headers
        h1_count=$(grep -c '^# ' "$f" || true)
        h2_count=$(grep -c '^## ' "$f" || true)
        h3_count=$(grep -c '^### ' "$f" || true)

        # Check for unclosed code blocks
        code_block_start=$(grep -c '```' "$f" || true)
        if [ $((code_block_start % 2)) -ne 0 ]; then
            echo "  ERROR: $filename has unclosed code block"
            syntax_errors=$((syntax_errors + 1))
        fi

        # Check for broken links (basic pattern check)
        broken_link_patterns=$(grep -c '\]\(()\)' "$f" || true)
        if [ "$broken_link_patterns" -gt 0 ]; then
            echo "  WARNING: $filename has $broken_link_patterns empty link targets"
            syntax_errors=$((syntax_errors + broken_link_patterns))
        fi

        if [ "$syntax_errors" -eq 0 ]; then
            echo "  OK: $filename (H1:$h1_count H2:$h2_count H3:$h3_count)"
        fi
    fi
done

echo ""
echo "--- Markdown Content Quality ---"
for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")

        # Check for empty paragraphs
        empty_paragraphs=$(grep -c '^$' "$f" || true)

        # Check for list items without proper formatting
        list_items=$(grep -c '^\s*[-*+]\s' "$f" || true)

        echo "  $filename: $empty_paragraphs empty lines, $list_items list items"
    fi
done

echo ""
echo "=== Markdown Health Check Complete ==="