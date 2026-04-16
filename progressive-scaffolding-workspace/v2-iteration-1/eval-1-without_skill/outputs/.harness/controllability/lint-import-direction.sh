#!/bin/bash
# lint-import-direction.sh — Enforce module layer hierarchy
# Prevents lower-level modules from importing higher-level ones.
# Adapts to common layer patterns: utils <- services <- tools/commands
#
# Usage:
#   ./lint-import-direction.sh [--fix] [--verbose]
#   ./lint-import-direction.sh --layers "utils,types" "services" "tools,commands"
#
# Exit codes:
#   0 = all imports conform
#   1 = violations found
#   2 = usage error

set -euo pipefail

VERBOSE=false
FIX=false
PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix)      FIX=true; shift ;;
        --verbose)  VERBOSE=true; shift ;;
        --layers)   shift; CUSTOM_LAYERS=(); while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do CUSTOM_LAYERS+=("$1"); shift; done ;;
        --help|-h)
            echo "Usage: $0 [--fix] [--verbose] [--layers group1 group2 group3]"
            echo ""
            echo "Checks that modules in lower layers don't import from higher layers."
            echo ""
            echo "Default layer hierarchy (low to high):"
            echo "  Layer 0: types, hooks, utils"
            echo "  Layer 1: services, state"
            echo "  Layer 2: tools, commands, components"
            echo ""
            echo "Options:"
            echo "  --fix       Print fix suggestions (doesn't modify files)"
            echo "  --verbose   Show all checked files"
            echo "  --layers    Custom layer groups (space-separated, low to high)"
            exit 0 ;;
        *) shift ;;
    esac
done

cd "$PROJECT_ROOT" || exit 2

# Define layer hierarchy (low to high)
if [[ ${#CUSTOM_LAYERS[@]} -gt 0 ]]; then
    LAYERS=("${CUSTOM_LAYERS[@]}")
else
    # Auto-detect layers from directory structure
    LAYERS=("types,hooks,utils" "services,state" "tools,commands,components")
fi

VIOLATIONS=0
TOTAL_CHECKS=0

echo "=== Import Direction Lint ==="
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
        continue  # Top layer, nothing to forbid
    fi

    # Check each directory in this layer
    for dir in "${LAYER_DIRS[@]}"; do
        if [[ ! -d "src/$dir" ]]; then
            continue
        fi

        while IFS= read -r -d '' file; do
            TOTAL_CHECKS=$((TOTAL_CHECKS + 1))

            for forbidden in "${FORBIDDEN_DIRS[@]}"; do
                # Check for imports from forbidden directories
                if grep -E "from ['\"].*${forbidden}/|import.*['\"].*${forbidden}/|require\(['\"].*${forbidden}/" \
                    "$file" 2>/dev/null | head -20; then

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
