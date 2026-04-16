#!/bin/bash
# Metrics collection script for harness-blogs

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Metrics ==="
echo ""

echo "--- File Metrics ---"
total_lines=0
total_words=0
total_chars=0

for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        lines=$(wc -l < "$f")
        words=$(wc -w < "$f")
        chars=$(wc -c < "$f")
        total_lines=$((total_lines + lines))
        total_words=$((total_words + words))
        total_chars=$((total_chars + chars))
    fi
done

echo "Total markdown lines: $total_lines"
echo "Total markdown words: $total_words"
echo "Total markdown characters: $total_chars"

echo ""
echo "--- Document Complexity Metrics ---"
for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")
        lines=$(wc -l < "$f")
        words=$(wc -w < "$f")
        # Calculate average words per line
        if [ "$lines" -gt 0 ]; then
            avg_wpl=$((words / lines))
        else
            avg_wpl=0
        fi
        echo "  $filename: $lines lines, $words words, ~$avg_wpl avg words/line"
    fi
done

echo ""
echo "--- Documentation Coverage ---"
doc_files=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "Total documentation files: $doc_files"

# Check for key documents
key_docs=("README.md" "CONTRIBUTING.md" "ARCHITECTURE.md")
for doc in "${key_docs[@]}"; do
    if [ -f "$PROJECT_ROOT/$doc" ]; then
        echo "  $doc: present"
    else
        echo "  $doc: missing"
    fi
done

echo ""
echo "=== Metrics Collection Complete ==="