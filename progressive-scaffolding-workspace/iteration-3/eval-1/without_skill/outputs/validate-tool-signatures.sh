#!/bin/bash
# scaffold/validate-tool-signatures.sh
# Validates that tool call() signatures follow the buildTool() pattern.
# GP-001 enforces arg order, this script goes further to validate the full shape.
#
# Expected patterns:
#   1. buildTool({...}) with call(args, context, ...) - canonical pattern
#   2. Class-based tools extending Tool with call(args, context) method
#   3. No standalone call(context, ...) or call(req, ...) patterns

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
SRC_DIR="${PROJECT_ROOT}/src"

echo "=== Tool Signature Validator ==="
echo "Source: ${SRC_DIR}"
echo ""

VIOLATIONS=0
WARNINGS=0
TOOLS_FOUND=0
TOOLS_VALID=0

# Check a single tool file
check_tool_file() {
    local file="$1"
    local relpath="${file#"$SRC_DIR/"}"

    TOOLS_FOUND=$((TOOLS_FOUND + 1))

    local has_buildtool=false
    local has_call_method=false
    local call_sig_correct=false

    # Check for buildTool pattern
    if grep -qE "buildTool\s*\(" "$file" 2>/dev/null; then
        has_buildtool=true

        # Validate buildTool call has proper structure
        # Should have: name, description, inputSchema, call
        if ! grep -A 50 "buildTool\s*(" "$file" 2>/dev/null | grep -qE "call\s*:\s*async\s*\("; then
            echo "WARNING: $relpath — buildTool() missing async call function"
            WARNINGS=$((WARNINGS + 1))
        fi

        # Check that call parameters are in correct order: (args, context)
        if grep -A 5 "call\s*:" "$file" 2>/dev/null | grep -qE "async\s*\(\s*context"; then
            echo "VIOLATION: $relpath — buildTool call() has context before args"
            VIOLATIONS=$((VIOLATIONS + 1))
        elif grep -A 5 "call\s*:" "$file" 2>/dev/null | grep -qE "async\s*\(\s*\{|async\s*\(\s*args"; then
            call_sig_correct=true
        fi
    fi

    # Check for class-based tool pattern (extends Tool)
    if grep -qE "(class|extends)\s+\w*Tool" "$file" 2>/dev/null; then
        has_call_method=true

        # Validate call method signature
        if grep -qE "async\s+call\s*\(\s*context\s*:" "$file" 2>/dev/null; then
            echo "VIOLATION: $relpath — class call() method has context as first param"
            VIOLATIONS=$((VIOLATIONS + 1))
        elif grep -qE "async\s+call\s*\(\s*(args|input|params)" "$file" 2>/dev/null; then
            call_sig_correct=true
        fi
    fi

    # Check for standalone export pattern
    if grep -qE "export\s+(async\s+)?function\s+call\s*\(" "$file" 2>/dev/null; then
        has_call_method=true
        if grep -qE "export\s+async\s+function\s+call\s*\(\s*context" "$file" 2>/dev/null; then
            echo "VIOLATION: $relpath — exported call() function has context as first param"
            VIOLATIONS=$((VIOLATIONS + 1))
        fi
    fi

    # Check for required tool elements
    if [[ "$has_buildtool" == "true" ]] || [[ "$has_call_method" == "true" ]]; then
        # Verify inputSchema exists
        if ! grep -qE "(inputSchema|input_schema|parameters)" "$file" 2>/dev/null; then
            echo "WARNING: $relpath — tool missing inputSchema definition"
            WARNINGS=$((WARNINGS + 1))
        fi

        if [[ "$call_sig_correct" == "true" ]] || [[ "$has_buildtool" == "true" ]]; then
            TOOLS_VALID=$((TOOLS_VALID + 1))
        fi
    fi
}

echo "Scanning tool directories..."
echo ""

# Scan all tool directories under src/tools/
while IFS= read -r -d '' dir; do
    # Each tool should be a directory with a main .ts file
    tool_name=$(basename "$dir")

    # Skip shared/ and testing/ directories
    [[ "$tool_name" == "shared" ]] && continue
    [[ "$tool_name" == "testing" ]] && continue

    # Find the main tool file (typically matches the directory name)
    main_file="${dir}/${tool_name}.ts"
    if [[ -f "$main_file" ]]; then
        check_tool_file "$main_file"
    else
        # Try finding any .ts file that's not UI.tsx or prompt.ts
        for f in "${dir}"/*.ts; do
            [[ -f "$f" ]] || continue
            basename_f=$(basename "$f")
            # The main file is usually the one matching the directory name or the largest
            if [[ "$basename_f" != "UI.tsx" ]] && [[ "$basename_f" != "prompt.ts" ]]; then
                check_tool_file "$f"
                break
            fi
        done
    fi
done < <(find "$SRC_DIR/tools" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

echo ""
echo "=== Tool Signature Summary ==="
echo "Tools found: ${TOOLS_FOUND}"
echo "Tools valid: ${TOOLS_VALID}"
echo "Violations: ${VIOLATIONS}"
echo "Warnings: ${WARNINGS}"

if [[ $VIOLATIONS -gt 0 ]]; then
    echo ""
    echo "FAILED: ${VIOLATIONS} tool signature violation(s) found"
    echo "Tool call() must use (args, context, ...) parameter order"
    exit 1
else
    echo ""
    echo "PASSED: All tool signatures valid"
    exit 0
fi
