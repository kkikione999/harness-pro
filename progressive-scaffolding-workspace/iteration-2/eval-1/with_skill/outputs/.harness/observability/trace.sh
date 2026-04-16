#!/bin/bash
# trace.sh - Correlation ID injection for tracing
# Usage: ./trace.sh <command> [args...]

CORRELATION_ID="${CORRELATION_ID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || echo "trace-$(date +%s)")}"
export CORRELATION_ID

echo "[$CORRELATION_ID] Starting: $@"

$@

EXIT_CODE=$?
echo "[$CORRELATION_ID] Finished with exit code: $EXIT_CODE"

exit $EXIT_CODE
