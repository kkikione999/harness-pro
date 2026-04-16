#!/bin/bash
# analyze-deps.sh - Dependency graph analysis and cycle detection
# Scans TypeScript imports to find dependency patterns and potential cycles.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC_DIR="$PROJECT_ROOT/src"

echo "=== Dependency Analysis ==="
echo ""

# Count total import statements
TOTAL_IMPORTS=$(grep -r "^import " "$SRC_DIR" --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
echo "Total import statements: $TOTAL_IMPORTS"
echo ""

# Analyze cross-layer imports
echo "=== Cross-Layer Import Analysis ==="
echo ""

# Define layers (ordered by dependency direction: lower layers should not import higher)
LAYERS=("types" "utils" "services" "hooks" "components" "tools" "commands")

for layer in "${LAYERS[@]}"; do
    if [ -d "$SRC_DIR/$layer" ]; then
        IMPORT_COUNT=$(grep -r "from ['\"]\.\.\?/" "$SRC_DIR/$layer" --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
        # Count imports from other layers
        CROSS_IMPORTS=0
        for other in "${LAYERS[@]}"; do
            if [ "$other" != "$layer" ] && [ -d "$SRC_DIR/$other" ]; then
                COUNT=$(grep -r "from ['\"]\.\..*/$other" "$SRC_DIR/$layer" --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
                if [ "$COUNT" -gt 0 ]; then
                    CROSS_IMPORTS=$((CROSS_IMPORTS + COUNT))
                fi
            fi
        done
        echo "  $layer: $IMPORT_COUNT imports ($CROSS_IMPORTS cross-layer)"
    fi
done

echo ""

# Check for circular dependencies (heuristic: A imports B and B imports A)
echo "=== Circular Dependency Heuristic ==="
echo ""

CYCLES_FOUND=0
for dir_a in "$SRC_DIR"/*/; do
    [ -d "$dir_a" ] || continue
    name_a=$(basename "$dir_a")
    for dir_b in "$SRC_DIR"/*/; do
        [ -d "$dir_b" ] || continue
        name_b=$(basename "$dir_b")
        [ "$name_a" \< "$name_b" ] || continue  # avoid duplicates

        # Check if A imports B
        a_imports_b=$(grep -rl "from ['\"]\.\..*$name_b" "$dir_a" --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')
        # Check if B imports A
        b_imports_a=$(grep -rl "from ['\"]\.\..*$name_a" "$dir_b" --include="*.ts" --include="*.tsx" 2>/dev/null | wc -l | tr -d ' ')

        if [ "$a_imports_b" -gt 0 ] && [ "$b_imports_a" -gt 0 ]; then
            echo "  POTENTIAL CYCLE: $name_a <-> $name_b ($a_imports_b + $b_imports_a files)"
            CYCLES_FOUND=$((CYCLES_FOUND + 1))
        fi
    done
done

if [ "$CYCLES_FOUND" -eq 0 ]; then
    echo "  No obvious circular dependencies detected at directory level."
else
    echo ""
    echo "  Found $CYCLES_FOUND potential circular dependency pair(s)."
    echo "  These should use src/types/ as the inversion layer (GP-002)."
fi

echo ""
echo "=== Dependency Summary ==="
echo "Total imports: $TOTAL_IMPORTS"
echo "Circular risks: $CYCLES_FOUND"
