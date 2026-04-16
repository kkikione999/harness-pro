#!/bin/bash
# trace.sh - Correlation ID injection for tracing eval operations
# Usage: ./trace.sh <command> [args...]

CORRELATION_ID="${CORRELATION_ID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null || echo "trace-$(date +%s)")}"
export CORRELATION_ID

EVAL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$EVAL_ROOT/logs"

mkdir -p "$LOG_DIR"

TRACE_LOG="$LOG_DIR/trace-$(date +%Y%m%d-%H%M%S).log"

# Log trace start
echo "[$CORRELATION_ID] [$(date -Iseconds)] Starting: $@" >> "$TRACE_LOG"

# Execute command
$@

EXIT_CODE=$?

# Log trace end
echo "[$CORRELATION_ID] [$(date -Iseconds)] Finished with exit code: $EXIT_CODE" >> "$TRACE_LOG"

exit $EXIT_CODE