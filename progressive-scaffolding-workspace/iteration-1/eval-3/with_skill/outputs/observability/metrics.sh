#!/bin/bash
# metrics.sh - Metrics endpoint query script for harness-blogs

set -e

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HARNESS_DIR/.." && pwd)"
METRICS_DIR="$PROJECT_ROOT/.harness/metrics"

# Parse arguments
FORMAT="text"  # text, json
METRIC_NAME=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --metric)
            METRIC_NAME="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

mkdir -p "$METRICS_DIR"

CORRELATION_ID="metrics-$$-$(date +%Y%m%d-%H%M%S)"

# Generate basic metrics for documentation project
echo "=== Metrics Query ===" if [ "$FORMAT" = "text" ]; then
    echo "Correlation ID: $CORRELATION_ID"
    echo "Timestamp: $(date -Iseconds)"
    echo ""

    # Count markdown files
    MD_COUNT=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    # Count total lines
    TOTAL_LINES=0
    for md in "$PROJECT_ROOT"/*.md; do
        if [ -f "$md" ]; then
            LINES=$(wc -l < "$md" 2>/dev/null || echo 0)
            TOTAL_LINES=$((TOTAL_LINES + LINES))
        fi
    done

    echo "Document Metrics:"
    echo "  markdown_files: $MD_COUNT"
    echo "  total_lines: $TOTAL_LINES"
    echo "  avg_lines_per_file: $(( TOTAL_LINES / (MD_COUNT > 0 ? MD_COUNT : 1) ))"

elif [ "$FORMAT" = "json" ]; then
    MD_COUNT=$(find "$PROJECT_ROOT" -maxdepth 1 -name "*.md" -type f 2>/dev/null | wc -l | tr -d ' ')
    TOTAL_LINES=0
    for md in "$PROJECT_ROOT"/*.md; do
        if [ -f "$md" ]; then
            LINES=$(wc -l < "$md" 2>/dev/null || echo 0)
            TOTAL_LINES=$((TOTAL_LINES + LINES))
        fi
    done

    printf '%s\n' '{"correlation_id": "'$CORRELATION_ID'", "timestamp": "'$(date -Iseconds)'", "metrics": {'
    printf '  "markdown_files": %d,\n' "$MD_COUNT"
    printf '  "total_lines": %d,\n' "$TOTAL_LINES"
    printf '  "avg_lines_per_file": %d\n' $(( TOTAL_LINES / (MD_COUNT > 0 ? MD_COUNT : 1) ))
    printf '}}'
fi

echo ""
exit 0
