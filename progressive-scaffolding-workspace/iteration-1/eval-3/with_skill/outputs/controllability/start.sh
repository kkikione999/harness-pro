#!/bin/bash
# start.sh - Start the development server for harness-blogs

set -e

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HARNESS_DIR/.." && pwd)"

echo "Starting harness-blogs development server..."

# Record start time for correlation
START_TIME=$(date +%s)
CORRELATION_ID="start-$$-$(date +%Y%m%d-%H%M%S)"
echo "CORRELATION_ID=$CORRELATION_ID"

# Add startup commands here
# Example: hugo server, mkdocs serve, etc.

echo "Server started at $(date)"
echo "Correlation ID: $CORRELATION_ID"

# Write PID for stop.sh to use
echo $$ > "$HARNESS_DIR/.server.pid"

exit 0
