#!/bin/bash
# metrics.sh - Collect and display project metrics
# Outputs JSON with file counts, complexity indicators, and lint statistics.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP=$(date -Iseconds)

# File counts by category
TOOLS=$(find "$PROJECT_ROOT/src/tools" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
COMMANDS=$(find "$PROJECT_ROOT/src/commands" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
HOOKS=$(find "$PROJECT_ROOT/src/hooks" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
COMPONENTS=$(find "$PROJECT_ROOT/src/components" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
SERVICES=$(find "$PROJECT_ROOT/src/services" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
UTILS=$(find "$PROJECT_ROOT/src/utils" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')
TOTAL=$(find "$PROJECT_ROOT/src" -name "*.ts" -o -name "*.tsx" 2>/dev/null | wc -l | tr -d ' ')

# Lint rule count
LINT_RULES=$(ls "$PROJECT_ROOT/rules/scripts"/lint-*.sh 2>/dev/null | wc -l | tr -d ' ')

# Log history
LOG_COUNT=$(ls "$PROJECT_ROOT/.harness/observability/logs"/test-auto-*.log 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF
{
  "project": "Open-ClaudeCode",
  "timestamp": "$TIMESTAMP",
  "file_metrics": {
    "total_ts_files": $TOTAL,
    "tools": $TOOLS,
    "commands": $COMMANDS,
    "hooks": $HOOKS,
    "components": $COMPONENTS,
    "services": $SERVICES,
    "utils": $UTILS
  },
  "lint_metrics": {
    "total_rules": $LINT_RULES,
    "test_runs_logged": $LOG_COUNT
  }
}
EOF
