#!/bin/bash
# Clean script for harness-blogs generated artifacts

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Clean ==="
echo ""

clean_count=0

# Clean generated-docs directory
if [ -d "$PROJECT_ROOT/generated-docs" ]; then
    rm -rf "$PROJECT_ROOT/generated-docs"
    echo "  Removed: generated-docs/"
    clean_count=$((clean_count + 1))
fi

# Clean .cache directory
if [ -d "$PROJECT_ROOT/.cache" ]; then
    rm -rf "$PROJECT_ROOT/.cache"
    echo "  Removed: .cache/"
    clean_count=$((clean_count + 1))
fi

# Clean any .DS_Store files
if find "$PROJECT_ROOT" -name ".DS_Store" -type f 2>/dev/null | grep -q .; then
    find "$PROJECT_ROOT" -name ".DS_Store" -type f -delete
    echo "  Removed: .DS_Store files"
    clean_count=$((clean_count + 1))
fi

echo ""
echo "Cleaned $clean_count item(s)"
echo ""
echo "=== Clean Complete ==="