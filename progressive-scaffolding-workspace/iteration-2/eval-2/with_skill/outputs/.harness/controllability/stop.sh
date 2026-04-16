#!/bin/bash
# controllability/stop.sh - Stop the progressive-scaffolding skill session

LOG_DIR="${PROJECT_ROOT:-.}/.harness/logs"

echo "Stopping progressive-scaffolding skill session"
echo "Session log: $LOG_DIR/session-$(date +%Y%m%d-%H%M%S).log"

# Note: This is a no-op for bash scripts since they don't run as daemons
# In a more complex setup, this would:
# - Kill background processes
# - Close log files
# - Clean up temporary files

echo "Progressive-scaffolding skill session ended"