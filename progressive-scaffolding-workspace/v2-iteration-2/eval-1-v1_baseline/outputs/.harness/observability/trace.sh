#!/bin/bash
# trace.sh - Correlation ID injection for tracing Open-ClaudeCode operations
# Usage: ./trace.sh <command> [args...]
#        CORRELATION_ID=<id> ./trace.sh <command> [args...]

CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "trace-$(date +%s)")}"
export CORRELATION_ID

if [ -z "$1" ]; then
    echo "Usage: ./trace.sh <command> [args...]"
    echo "Environment:"
    echo "  CORRELATION_ID  - Set correlation ID manually"
    echo ""
    echo "Examples:"
    echo "  ./trace.sh ./start.sh"
    echo "  CORRELATION_ID=my-session ./trace.sh ./verify.sh"
    exit 0
fi

echo "[$CORRELATION_ID] TRACE: Starting: $@"

START_TIME=$(date +%s%3N)

$@
ACT_EXIT_CODE=$?

END_TIME=$(date +%s%3N)
DURATION_MS=$((END_TIME - START_TIME))

echo "[$CORRELATION_ID] TRACE: Finished: $@ (exit $ACT_EXIT_CODE, ${DURATION_MS}ms)"

exit $ACT_EXIT_CODE
