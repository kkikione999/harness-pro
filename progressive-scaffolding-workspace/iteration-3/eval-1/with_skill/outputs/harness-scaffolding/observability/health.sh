#!/bin/bash
# health.sh - Project health check with JSON output
# For a CLI project, health = structure integrity + last lint result.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.harness/observability/logs"
TIMESTAMP=$(date -Iseconds)

# Count source files
TS_COUNT=$(find "$PROJECT_ROOT/src" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
TOOL_COUNT=$(find "$PROJECT_ROOT/src/tools" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
CMD_COUNT=$(find "$PROJECT_ROOT/src/commands" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
LINT_COUNT=$(ls "$PROJECT_ROOT/rules/scripts"/lint-*.sh 2>/dev/null | wc -l | tr -d ' ')

# Check last test result
LAST_RESULT="none"
LATEST_LOG=$(ls -t "$LOG_DIR"/test-auto-*.log 2>/dev/null | head -1)
if [ -n "$LATEST_LOG" ]; then
    if grep -q "PASSED\|All.*passed" "$LATEST_LOG" 2>/dev/null; then
        LAST_RESULT="pass"
    else
        LAST_RESULT="fail"
    fi
fi

# Check for PID file (running CLI)
CLI_STATUS="not_running"
PID_FILE="$PROJECT_ROOT/.harness/Open_ClaudeCode.pid"
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        CLI_STATUS="running"
    fi
fi

# Output JSON
cat <<EOF
{
  "project": "Open-ClaudeCode",
  "timestamp": "$TIMESTAMP",
  "structure": {
    "source_files": $TS_COUNT,
    "tool_files": $TOOL_COUNT,
    "command_files": $CMD_COUNT,
    "lint_scripts": $LINT_COUNT,
    "src_dir": $([ -d "$PROJECT_ROOT/src" ] && echo "true" || echo "false"),
    "package_json": $([ -f "$PROJECT_ROOT/package/package.json" ] && echo "true" || echo "false"),
    "check_py": $([ -f "$PROJECT_ROOT/rules/scripts/check.py" ] && echo "true" || echo "false")
  },
  "cli_status": "$CLI_STATUS",
  "last_lint_result": "$LAST_RESULT",
  "harness_version": "1.0.0"
}
EOF
