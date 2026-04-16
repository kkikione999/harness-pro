#!/bin/bash
# scaffold/lint-import-direction.sh
# Validates dependency direction across module layers.
# Enforces: utils <- types <- services <- tools <- commands <- components
# Lower layers must NOT import from higher layers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

# Default to project root if not overridden
SRC_DIR="${PROJECT_ROOT}/src"

echo "=== Import Direction Linter ==="
echo "Source: ${SRC_DIR}"
echo ""

# Layer hierarchy: lower number = lower layer (foundational)
# A file in layer N must NOT import from layer N+1 or higher
declare -A LAYER_RANK
LAYER_RANK[types]=0
LAYER_RANK[utils]=1
LAYER_RANK[constants]=1
LAYER_RANK[schemas]=1
LAYER_RANK[ink]=2
LAYER_RANK[state]=2
LAYER_RANK[bootstrap]=2
LAYER_RANK[context]=2
LAYER_RANK[hooks]=3
LAYER_RANK[services]=3
LAYER_RANK[memdir]=3
LAYER_RANK[vendor]=3
LAYER_RANK[plugins]=4
LAYER_RANK[tools]=4
LAYER_RANK[tasks]=4
LAYER_RANK[commands]=5
LAYER_RANK[components]=5
LAYER_RANK[screens]=5
LAYER_RANK[outputStyles]=5
LAYER_RANK[entrypoints]=6
LAYER_RANK[native-ts]=6
LAYER_RANK[bridge]=6
LAYER_RANK[cli]=6
LAYER_RANK[coordinator]=6
LAYER_RANK[buddy]=6
LAYER_RANK[remote]=6
LAYER_RANK[moreright]=6
LAYER_RANK[voice]=6
LAYER_RANK[keybindings]=6
LAYER_RANK[vim]=6
LAYER_RANK[upstreamproxy]=6

VIOLATIONS=0
WARNINGS=0
CHECKED=0

# Get the layer of a file path
get_layer() {
    local filepath="$1"
    # Extract the first directory component under src/
    local relpath="${filepath#"$SRC_DIR/"}"
    local layer="${relpath%%/*}"
    echo "$layer"
}

# Get layer rank (returns 99 for unknown layers)
get_rank() {
    local layer="$1"
    if [[ -n "${LAYER_RANK[$layer]+_}" ]]; then
        echo "${LAYER_RANK[$layer]}"
    else
        echo "99"
    fi
}

# Find all import sources in a file and check their layers
check_file() {
    local filepath="$1"
    local file_layer
    file_layer=$(get_layer "$filepath")
    local file_rank
    file_rank=$(get_rank "$file_layer")

    # Skip files that are in root src/ (no layer)
    if [[ "$file_layer" == "$(basename "$filepath")" ]]; then
        return
    fi

    # Extract all static imports from the file
    # Match: import ... from 'src/LAYER/...' or from './...' or from '../...'
    while IFS= read -r import_line; do
        # Parse the import path
        local import_path
        import_path=$(echo "$import_line" | grep -oE "from\s+['\"]([^'\"]+)['\"]" | sed "s/from\s*['\"]//;s/['\"]$//" || true)

        [[ -z "$import_path" ]] && continue

        # Only check relative imports that reference src/ modules
        local import_layer=""
        if [[ "$import_path" == src/* ]]; then
            # Absolute src import: src/hooks/useSomething.ts -> hooks
            import_layer="${import_path#src/}"
            import_layer="${import_layer%%/*}"
        elif [[ "$import_path" == ./* ]] || [[ "$import_path" == ../* ]]; then
            # Relative import: resolve against file's directory
            local file_dir
            file_dir=$(dirname "$filepath")
            local resolved
            resolved=$(cd "$file_dir" && realpath --relative-to="$SRC_DIR" "$import_path" 2>/dev/null || echo "")
            if [[ -n "$resolved" ]]; then
                import_layer="${resolved%%/*}"
            fi
        else
            # External package import, skip
            continue
        fi

        [[ -z "$import_layer" ]] && continue

        local import_rank
        import_rank=$(get_rank "$import_layer")

        # Check: file is in a lower layer importing from a higher layer
        if [[ "$file_rank" -lt "$import_rank" ]]; then
            local severity="VIOLATION"
            # Types importing from utils is a warning, not error
            if [[ "$file_rank" -le 1 && "$import_rank" -le 2 ]]; then
                severity="WARNING"
                WARNINGS=$((WARNINGS + 1))
            else
                VIOLATIONS=$((VIOLATIONS + 1))
            fi
            echo "$severity: $(basename "$filepath") ($file_layer, rank=$file_rank) imports from $import_layer (rank=$import_rank)"
            echo "  File: $filepath"
            echo "  Import: $import_path"
        fi

    done < <(grep -nE "import\s+.*from\s+['\"]" "$filepath" 2>/dev/null || true)

    CHECKED=$((CHECKED + 1))
}

echo "Scanning TypeScript files..."

# Process all .ts and .tsx files
while IFS= read -r -d '' file; do
    check_file "$file"
done < <(find "$SRC_DIR" -name "*.ts" -o -name "*.tsx" -print0 2>/dev/null | head -500)

echo ""
echo "=== Import Direction Summary ==="
echo "Files checked: $CHECKED"
echo "Violations: $VIOLATIONS"
echo "Warnings: $WARNINGS"

if [[ $VIOLATIONS -gt 0 ]]; then
    echo ""
    echo "FAILED: $VIOLATIONS import direction violation(s) found"
    echo "Rule: Lower layers (types, utils) must not import from higher layers (tools, commands)"
    exit 1
elif [[ $WARNINGS -gt 0 ]]; then
    echo ""
    echo "PASSED WITH WARNINGS: $WARNINGS minor layer boundary crossing(s)"
    exit 0
else
    echo ""
    echo "PASSED: All import directions comply with layer hierarchy"
    exit 0
fi
