#!/bin/bash
# metrics.sh - Collect and display metrics for eval outputs
# Usage: ./metrics.sh [summary|detailed|json]

EVAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$EVAL_ROOT/logs"
METRICS_FILE="$EVAL_ROOT/metrics.json"

mkdir -p "$LOG_DIR"

MODE="${1:-summary}"

collect_metrics() {
    TIMESTAMP=$(date -Iseconds)
    EVAL_START="${EVAL_START:-$(date +%s)}"
    CURRENT_TIME=$(date +%s)
    DURATION=$((CURRENT_TIME - EVAL_START))

    # Count files by type
    MD_COUNT=$(find "$EVAL_ROOT" -type f -name "*.md" 2>/dev/null | wc -l)
    JSON_COUNT=$(find "$EVAL_ROOT" -type f -name "*.json" 2>/dev/null | wc -l)
    LOG_COUNT=$(find "$EVAL_ROOT" -type f -name "*.log" 2>/dev/null | wc -l)
    SH_COUNT=$(find "$EVAL_ROOT" -type f -name "*.sh" 2>/dev/null | wc -l)

    # Total files excluding this script
    TOTAL_FILES=$(find "$EVAL_ROOT" -type f ! -name "metrics.sh" ! -name "health.sh" ! -name "report.sh" ! -name "trace.sh" 2>/dev/null | wc -l)

    # Log size
    LOG_SIZE=$(find "$LOG_DIR" -type f -name "*.log" 2>/dev/null | xargs du -b 2>/dev/null | awk '{sum+=$1} END {print sum+0}')

    cat << EOF
{
    "timestamp": "$TIMESTAMP",
    "duration_seconds": $DURATION,
    "files": {
        "markdown": $MD_COUNT,
        "json": $JSON_COUNT,
        "logs": $LOG_COUNT,
        "scripts": $SH_COUNT,
        "total": $TOTAL_FILES
    },
    "log_size_bytes": $LOG_SIZE
}
EOF
}

case "$MODE" in
    summary)
        METRICS=$(collect_metrics)
        echo "=== Eval Metrics Summary ==="
        echo "$METRICS" | python3 -c "import json,sys; d=json.load(sys.stdin); print(f\"Duration: {d['duration_seconds']}s\"); print(f\"Files: md={d['files']['markdown']}, json={d['files']['json']}, logs={d['files']['logs']}, scripts={d['files']['scripts']}\"); print(f\"Total files: {d['files']['total']}\"); print(f\"Log size: {d['log_size_bytes']} bytes\")" 2>/dev/null || echo "$METRICS"
        ;;
    detailed)
        echo "=== Detailed Metrics ==="
        collect_metrics
        ;;
    json)
        collect_metrics
        ;;
    *)
        echo "Usage: ./metrics.sh [summary|detailed|json]"
        ;;
esac

# Save metrics if json mode or on request
if [ "$MODE" = "json" ] || [ "$2" = "--save" ]; then
    collect_metrics > "$METRICS_FILE"
fi