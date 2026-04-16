#!/bin/bash
# trace.sh - Correlation ID injection for command tracing
# Usage: ./trace.sh <command> [args...]
# Wraps any command with a correlation ID for log attribution.

CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || python3 -c 'import uuid; print(uuid.uuid4())' 2>/dev/null || echo "trace-$(date +%s)")}"
export CORRELATION_ID

if [ $# -eq 0 ]; then
    echo "Usage: ./trace.sh <command> [args...]"
    echo "Wraps any command with a correlation ID for log attribution."
    exit 1
fi

echo "[$CORRELATION_ID] Starting: $*"

# Run the command, prefixing all output with the correlation ID
"$@" 2>&1 | while IFS= read -r line; do
    echo "[$CORRELATION_ID] $line"
done

EXIT_CODE=${PIPESTATUS[0]}
echo "[$CORRELATION_ID] Finished with exit code: $EXIT_CODE"

exit "$EXIT_CODE"
