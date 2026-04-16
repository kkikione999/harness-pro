#!/bin/bash
# scaffold/lint-export-counts.sh
# Detects potential dead code by analyzing export/import ratios per module.
# Modules with many exports but few imports are flagged as potential dead code.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
SRC_DIR="${PROJECT_ROOT}/src"

echo "=== Export/Import Ratio Analyzer ==="
echo "Source: ${SRC_DIR}"
echo ""

# Thresholds
MAX_EXPORTS_WITHOUT_IMPORTS=10  # Flag files with more than N exports and 0 imports
MIN_EXPORT_COUNT=3              # Only analyze files with at least N exports

declare -A EXPORT_COUNTS
declare -A IMPORT_COUNTS
declare -A FILE_EXPORTS  # file -> list of exported symbols
CHECKED=0

# Phase 1: Count exports per file
echo "Phase 1: Counting exports..."
while IFS= read -r -d '' file; do
    local_exports=0

    # Count named exports: export const, export function, export class, export type, export interface
    local_exports=$(grep -cE "^\s*export\s+(const|let|var|function|class|type|interface|enum|default)" "$file" 2>/dev/null || echo "0")

    # Count re-exports: export { ... } from, export * from
    local_reexports=$(grep -cE "^\s*export\s+(\{[^}]*\}\s+from|\\\*\s+from)" "$file" 2>/dev/null || echo "0")

    total_exports=$((local_exports + local_reexports))

    if [[ "$total_exports" -ge "$MIN_EXPORT_COUNT" ]]; then
        relpath="${file#"$SRC_DIR/"}"
        EXPORT_COUNTS["$relpath"]=$total_exports
        IMPORT_COUNTS["$relpath"]=0  # Initialize import counter
        CHECKED=$((CHECKED + 1))
    fi
done < <(find "$SRC_DIR" -name "*.ts" -o -name "*.tsx" -print0 2>/dev/null)

echo "  Found ${CHECKED} files with >= ${MIN_EXPORT_COUNT} exports"

# Phase 2: Count imports referencing each file
echo "Phase 2: Counting cross-file imports..."
while IFS= read -r -d '' file; do
    # Find all imports from relative paths or src/ paths
    while IFS= read -r import_path; do
        [[ -z "$import_path" ]] && continue

        # Resolve relative imports to target file
        file_dir=$(dirname "$file")
        resolved=""

        if [[ "$import_path" == src/* ]]; then
            resolved="${PROJECT_ROOT}/${import_path}"
        elif [[ "$import_path" == ./* ]] || [[ "$import_path" == ../* ]]; then
            resolved=$(cd "$file_dir" 2>/dev/null && realpath --relative-to="$SRC_DIR" "$import_path" 2>/dev/null || echo "")
        fi

        # Strip extensions and index
        resolved="${resolved%.ts}"
        resolved="${resolved%.tsx}"
        resolved="${resolved%.js}"
        resolved="${resolved%.jsx}"
        resolved="${resolved%/index}"

        # Increment import count for the resolved target
        if [[ -n "$resolved" ]] && [[ -n "${IMPORT_COUNTS[$resolved]+_}" ]]; then
            current=${IMPORT_COUNTS["$resolved"]}
            IMPORT_COUNTS["$resolved"]=$((current + 1))
        fi
    done < <(grep -oE "from\s+['\"]([^'\"]+)['\"]" "$file" 2>/dev/null | sed "s/from\s*['\"]//;s/['\"]$//" || true)
done < <(find "$SRC_DIR" -name "*.ts" -o -name "*.tsx" -print0 2>/dev/null)

# Phase 3: Report files with high export/import ratio
echo ""
echo "Phase 3: Identifying potential dead code..."
echo ""

SUSPECTS=0
HIGH_RATIO=0

# Sort by ratio (exports / imports) descending
for file in "${!EXPORT_COUNTS[@]}"; do
    exports=${EXPORT_COUNTS["$file"]}
    imports=${IMPORT_COUNTS["$file"]:-0}

    # Skip index files (barrel re-exports)
    [[ "$(basename "$file")" == "index.ts" ]] && continue
    [[ "$(basename "$file")" == "index.tsx" ]] && continue

    if [[ "$imports" -eq 0 && "$exports" -ge "$MAX_EXPORTS_WITHOUT_IMPORTS" ]]; then
        echo "SUSPECT: $file"
        echo "  Exports: $exports, Imports: $imports (ratio: inf)"
        SUSPECTS=$((SUSPECTS + 1))
    elif [[ "$imports" -gt 0 ]]; then
        ratio=$(echo "scale=1; $exports / $imports" | bc 2>/dev/null || echo "0")
        # Flag high ratio (more than 5x exports to imports)
        if (( $(echo "$ratio > 5" | bc -l 2>/dev/null || echo "0") )); then
            echo "HIGH RATIO: $file"
            echo "  Exports: $exports, Imports: $imports (ratio: ${ratio}x)"
            HIGH_RATIO=$((HIGH_RATIO + 1))
        fi
    fi
done

echo ""
echo "=== Export/Import Summary ==="
echo "Files analyzed: ${CHECKED}"
echo "Suspect files (0 imports, >= ${MAX_EXPORTS_WITHOUT_IMPORTS} exports): ${SUSPECTS}"
echo "High ratio files (>5x exports to imports): ${HIGH_RATIO}"

if [[ $SUSPECTS -gt 0 ]]; then
    echo ""
    echo "WARNING: ${SUSPECTS} file(s) may contain dead code (exported but never imported)"
    exit 0  # Warning only, not a hard failure
else
    echo ""
    echo "PASSED: No obvious dead code detected"
    exit 0
fi
