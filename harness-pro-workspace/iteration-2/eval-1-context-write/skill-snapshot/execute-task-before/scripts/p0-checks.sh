#!/bin/bash
# p0-checks.sh — Universal P0 checks that apply to all projects
# Run at milestone boundaries and before completion
# Exit non-zero if any CRITICAL violation found

set -euo pipefail

PROJECT_ROOT="$(pwd)"

VIOLATIONS=0

# --- P0-001: No hardcoded secrets ---
# Catches common secret patterns in source files (not in .git, node_modules, etc.)
check_secrets() {
    # Match common secret patterns: variable names (camelCase and UPPER_SNAKE) + long string values
    local pattern='(api[_-]?key|secret|password|token|private[_-]?key|auth[_-]?token|bearer)\s*[:=]\s*["\x27][^"\x27]{8,}'
    local files
    files=$(git ls-files --cached --others --exclude-standard 2>/dev/null | grep -vE '\.(lock|sum|mod|pbxproj)$' || find . -type f \( -name "*.swift" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.java" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/vendor/*" 2>/dev/null)

    local matches
    matches=$(echo "$files" | xargs grep -liE "$pattern" 2>/dev/null || true)

    if [ -n "$matches" ]; then
        echo "CRITICAL P0-001: Hardcoded secrets found in:"
        echo "$matches" | while read -r f; do
            echo "  $f"
        done
        echo "Fix: Move secrets to environment variables or secret manager"
        VIOLATIONS=$((VIOLATIONS + 1))
    else
        echo "PASS P0-001: No hardcoded secrets"
    fi
}

# --- P0-002: File size limit (800 lines) ---
check_file_size() {
    local MAX_LINES=800
    local files
    files=$(git ls-files --cached --others --exclude-standard 2>/dev/null | grep -vE '\.(lock|sum|min\.js|min\.css|generated|pb\.go)$' || find . -type f \( -name "*.swift" -o -name "*.ts" -o -name "*.js" -o -name "*.py" -o -name "*.go" -o -name "*.java" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/vendor/*" 2>/dev/null)

    local oversize
    oversize=$(echo "$files" | while read -r f; do
        [ -z "$f" ] && continue
        lines=$(wc -l < "$f" 2>/dev/null || echo 0)
        if [ "$lines" -gt "$MAX_LINES" ]; then
            echo "$f ($lines lines)"
        fi
    done)

    if [ -n "$oversize" ]; then
        echo "CRITICAL P0-002: Files exceed ${MAX_LINES}-line limit:"
        echo "$oversize" | while read -r line; do
            echo "  $line"
        done
        echo "Fix: Split into smaller, focused files"
        VIOLATIONS=$((VIOLATIONS + 1))
    else
        echo "PASS P0-002: All files under ${MAX_LINES} lines"
    fi
}

# --- P0-003: No TODO/FIXME in staged changes ---
check_todos() {
    local todos
    todos=$(git diff --cached --name-only 2>/dev/null | xargs grep -nE '(TODO|FIXME|HACK|XXX):' 2>/dev/null || true)

    # If no git staging, check all tracked source files
    if [ -z "$todos" ]; then
        todos=$(git ls-files --cached 2>/dev/null | grep -vE '\.(lock|sum|mod)$' | xargs grep -nE '(TODO|FIXME|HACK|XXX):' 2>/dev/null || true)
    fi

    if [ -n "$todos" ]; then
        echo "WARNING P0-003: TODO/FIXME found (advisory, not blocking):"
        echo "$todos" | head -5
    else
        echo "PASS P0-003: No TODO/FIXME residuals"
    fi
}

# --- Run all checks ---
echo "=== P0 Universal Checks ==="
echo "Project: $PROJECT_ROOT"
echo ""

check_secrets
check_file_size
check_todos

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
    echo "FAILED: $VIOLATIONS CRITICAL violation(s) found"
    exit 1
else
    echo "PASSED: All P0 checks clean"
    exit 0
fi
