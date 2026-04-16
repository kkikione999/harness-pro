#!/bin/bash
# controllability/start.sh - Start the progressive-scaffolding skill

SKILL_ROOT="${PROJECT_ROOT:-.}"
LOG_DIR="$SKILL_ROOT/.harness/logs"

# Initialize logging
mkdir -p "$LOG_DIR"

# Generate correlation ID for this session
export CORRELATION_ID=$(uuidgen 2>/dev/null || date -u +"%Y%m%d%H%M%S-%RANDOM")
export CORRELATION_ID="${CORRELATION_ID%%[$'\n\r']}"  # Trim whitespace

echo "[$CORRELATION_ID] Starting progressive-scaffolding skill session"
echo "[$CORRELATION_ID] Log directory: $LOG_DIR"
echo "[$CORRELATION_ID] Skill root: $SKILL_ROOT"

# Log to file
exec > >(tee -a "$LOG_DIR/session-$(date +%Y%m%d-%H%M%S).log")
exec 2>&1

# Export for child processes
export SKILL_ROOT
export LOG_DIR

echo "Progressive-scaffolding skill started"
echo "Available commands:"
echo "  make assess        - Run assessment probes"
echo "  make generate      - Generate scaffolding"
echo "  make verify        - Verify scaffolding"
echo "  make help          - Show all commands"