#!/bin/bash
# observability/log.sh - Structured log query for progressive-scaffolding skill

LOG_DIR="${PROJECT_ROOT:-.}/.harness/logs"
CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo 'unknown')}"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Log with correlation ID
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "{\"timestamp\":\"$timestamp\",\"level\":\"$level\",\"correlation_id\":\"$CORRELATION_ID\",\"message\":\"$message\"}"
}

# Recent logs (last 20 lines)
recent() {
    if [ -f "$LOG_DIR/skill.log" ]; then
        echo "=== Recent Logs ==="
        tail -20 "$LOG_DIR/skill.log"
    else
        echo "No logs found at $LOG_DIR/skill.log"
    fi
}

# Search logs
search() {
    local pattern="$1"
    if [ -f "$LOG_DIR/skill.log" ]; then
        grep -i "$pattern" "$LOG_DIR/skill.log"
    else
        echo "No logs found at $LOG_DIR/skill.log"
    fi
}

# Follow logs (tail -f equivalent)
follow() {
    if [ -f "$LOG_DIR/skill.log" ]; then
        tail -f "$LOG_DIR/skill.log"
    else
        echo "No logs found at $LOG_DIR/skill.log"
    fi
}

# Execute command and log output
exec_with_log() {
    local cmd="$1"
    log "INFO" "Executing: $cmd"
    $cmd 2>&1 | tee -a "$LOG_DIR/skill.log"
    local exit_code=${PIPESTATUS[0]}
    if [ $exit_code -eq 0 ]; then
        log "INFO" "Command succeeded: $cmd"
    else
        log "ERROR" "Command failed: $cmd (exit $exit_code)"
    fi
    return $exit_code
}

# Main
case "${1:-recent}" in
    recent)
        recent
        ;;
    search)
        search "${2:-.}"
        ;;
    follow)
        follow
        ;;
    exec)
        exec_with_log "${2:-echo no-command}"
        ;;
    *)
        echo "Usage: $0 {recent|search|follow|exec}"
        echo "  recent  - Show recent logs (default)"
        echo "  search  - Search logs by pattern"
        echo "  follow  - Follow log output"
        echo "  exec    - Execute command with logging"
        exit 1
        ;;
esac