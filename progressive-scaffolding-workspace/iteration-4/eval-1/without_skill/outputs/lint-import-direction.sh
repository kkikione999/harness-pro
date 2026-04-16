#!/bin/bash
# lint-import-direction.sh - Enforce module layer hierarchy
# Checks that imports follow the dependency direction defined by AGENTS.md:
#   types -> utils -> services -> hooks -> components -> tools/commands
# Higher layers should NOT import from lower layers (violates architecture).

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"

echo "=== Import Direction Lint ==="
echo ""

# Layer hierarchy (lower = more foundational)
# types -> utils -> services -> hooks -> components -> tools -> commands
# Rule: higher layers should NOT be imported by lower layers.
# This is a simplified check; see AGENTS.md for full rules.

VIOLATIONS=0

# Check that tools/ and commands/ are not imported by foundational layers
echo "Checking: foundational layers should not import tools/commands..."
for layer in types utils services constants schemas; do
    dir="$SRC_DIR/$layer"
    [ -d "$dir" ] || continue

    # Check for imports of tools or commands from this layer
    TOOL_IMPORTS=$(grep -rn "from ['\"]\.\..*tools\|from ['\"]\.\..*commands" "$dir" --include="*.ts" --include="*.tsx" 2>/dev/null || true)
    if [ -n "$TOOL_IMPORTS" ]; then
        echo "VIOLATION: $layer/ imports tools or commands (upward dependency):"
        echo "$TOOL_IMPORTS" | head -5
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
done

echo ""
echo "Checking: components should not import commands..."
COMP_DIR="$SRC_DIR/components"
if [ -d "$COMP_DIR" ]; then
    CMD_IMPORTS=$(grep -rn "from ['\"]\.\..*commands" "$COMP_DIR" --include="*.ts" --include="*.tsx" 2>/dev/null || true)
    if [ -n "$CMD_IMPORTS" ]; then
        echo "VIOLATION: components/ imports commands (upward dependency):"
        echo "$CMD_IMPORTS" | head -5
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
fi

echo ""
echo "Checking: services should not import hooks or components..."
SERV_DIR="$SRC_DIR/services"
if [ -d "$SERV_DIR" ]; then
    UP_IMPORTS=$(grep -rn "from ['\"]\.\..*hooks\|from ['\"]\.\..*components" "$SERV_DIR" --include="*.ts" --include="*.tsx" 2>/dev/null || true)
    if [ -n "$UP_IMPORTS" ]; then
        echo "VIOLATION: services/ imports hooks or components (upward dependency):"
        echo "$UP_IMPORTS" | head -5
        VIOLATIONS=$((VIOLATIONS + 1))
    fi
fi

echo ""
if [ "$VIOLATIONS" -gt 0 ]; then
    echo "FAILED: $VIOLATIONS violation(s) found"
    echo "Rule: imports must follow the dependency direction defined in AGENTS.md"
    exit 1
else
    echo "PASSED: No import direction violations found"
    exit 0
fi
