#!/bin/bash
# Status observability script for harness-blogs

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Status Report ==="
echo ""

echo "Project: harness-blogs"
echo "Location: $PROJECT_ROOT"
echo "Date: $(date)"
echo ""

echo "--- File Counts ---"
md_count=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
echo "Markdown files (.md): $md_count"

echo ""
echo "--- Directory Contents ---"
echo "Root level files:"
ls -la "$PROJECT_ROOT"/*.md 2>/dev/null | awk '{print "  " $9 " (" $5 " bytes)"}' || echo "  (none)"

echo ""
echo "--- Markdown Files ---"
for f in "$PROJECT_ROOT"/*.md; do
    if [ -f "$f" ]; then
        filename=$(basename "$f")
        line_count=$(wc -l < "$f")
        word_count=$(wc -w < "$f")
        echo "  $filename: $line_count lines, $word_count words"
    fi
done

echo ""
echo "--- Workspace Structure ---"
if [ -d "$PROJECT_ROOT/progressive-scaffolding-workspace" ]; then
    echo "  progressive-scaffolding-workspace: present"
    find "$PROJECT_ROOT/progressive-scaffolding-workspace" -type d 2>/dev/null | while read -r dir; do
        echo "    $dir"
    done
else
    echo "  progressive-scaffolding-workspace: not present"
fi

echo ""
echo "=== Status Report Complete ==="