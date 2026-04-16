#!/bin/bash
# lint-import-direction.sh — Enforce module layer hierarchy for Open-ClaudeCode
# Prevents lower-level modules from importing higher-level ones.
#
# Layer hierarchy (low to high):
#   Layer 0: types, constants, hooks
#   Layer 1: utils, ink, state, context
#   Layer 2: services, tools, components
#   Layer 3: commands, screens, entrypoints, main
#
# Usage:
#   ./lint-import-direction.sh [--fix] [--verbose]
#
# Exit codes:
#   0 = all imports conform
#   1 = violations found

set -e

PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
VERBOSE=false
FIX=false
VIOLATIONS=0
TOTAL_CHECKS=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix)      FIX=true; shift ;;
        --verbose)  VERBOSE=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--fix] [--verbose]"
            echo ""
            echo "Checks that modules in lower layers don't import from higher layers."
            echo ""
            echo "Layer hierarchy (low to high):"
            echo "  Layer 0: types, constants, hooks"
            echo "  Layer 1: utils, ink, state, context"
            echo "  Layer 2: services, tools, components"
            echo "  Layer 3: commands, screens, entrypoints, main"
            exit 0 ;;
        *) shift ;;
    esac
done

cd "$PROJECT_ROOT" || exit 2

# Layer hierarchy (low to high)
LAYERS=(
    "types,constants,hooks"
    "utils,ink,state,context"
    "services,tools,components"
    "commands,screens,entrypoints,main"
)

echo "=== Import Direction Lint (Open-ClaudeCode) ==="
echo "Layer hierarchy (${#LAYERS[@]} layers):"
for i in "${!LAYERS[@]}"; do
    echo "  Layer $i: ${LAYERS[$i]}"
done
echo ""

# For each layer, check that it doesn't import from higher layers
for layer_idx in "${!LAYERS[@]}"; do
    IFS=',' read -ra LAYER_DIRS <<< "${LAYERS[$layer_idx]}"

    # Get directories in higher layers (forbidden imports)
    FORBIDDEN_DIRS=()
    for higher_idx in $(seq $((layer_idx + 1)) $((${#LAYERS[@]} - 1))); do
        IFS=',' read -ra HIGHER_DIRS <<< "${LAYERS[$higher_idx]}"
        FORBIDDEN_DIRS+=("${HIGHER_DIRS[@]}")
    done

    if [[ ${#FORBIDDEN_DIRS[@]} -eq 0 ]]; then
        continue
    fi

    # Check each directory in this layer
    for dir in "${LAYER_DIRS[@]}"; do
        if [[ ! -d "src/$dir" ]]; then
            continue
        fi

        while IFS= read -r -d '' file; do
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            $VERBOSE && echo "  Checking: src/$dir/$(basename "$file")"

            for forbidden in "${FORBIDDEN_DIRS[@]}"; do
                if grep -E "from ['\"].*${forbidden}/|import.*['\"].*${forbidden}/|require\(['\"].*${forbidden}/" \
                    "$file" 2>/dev/null | head -20 | grep -q .; then

                    matching_lines=$(grep -cE "from ['\"].*${forbidden}/|import.*['\"].*${forbidden}/|require\(['\"].*${forbidden}/" "$file" 2>/dev/null || echo "0")

                    echo "VIOLATION: src/$dir/$(basename "$file") imports from src/$forbidden/ ($matching_lines imports)"
                    echo "  Layer $layer_idx ($dir) -> Layer $((layer_idx + 1)) ($forbidden)"

                    if $FIX; then
                        echo "  FIX: Move shared logic to a lower layer (types/ or utils/)"
                    fi

                    VIOLATIONS=$((VIOLATIONS + 1))
                fi
            done
        done < <(find "src/$dir" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \) -print0 2>/dev/null)
    done
done

echo ""
echo "Results: $VIOLATIONS violations in $TOTAL_CHECKS files checked"

if [[ $VIOLATIONS -gt 0 ]]; then
    echo "STATUS: FAIL"
    exit 1
else
    echo "STATUS: PASS"
    exit 0
fi
