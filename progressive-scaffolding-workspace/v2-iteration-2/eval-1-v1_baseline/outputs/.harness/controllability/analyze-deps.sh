#!/bin/bash
# analyze-deps.sh — Dependency graph analysis with cycle detection for Open-ClaudeCode
# Scans TypeScript imports and builds a dependency graph, then detects cycles via DFS.
# Compatible with bash 3.2+ (no associative arrays)
#
# Usage:
#   ./analyze-deps.sh [--cycles] [--json] [--dot]
#
# Exit codes:
#   0 = no cycles found
#   1 = cycles detected

PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
MODE="full"
OUTPUT_JSON=false
OUTPUT_DOT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cycles) MODE="cycles"; shift ;;
        --json)   OUTPUT_JSON=true; shift ;;
        --dot)    OUTPUT_DOT=true; shift ;;
        --help|-h)
            echo "Usage: $0 [--cycles] [--json] [--dot]"
            echo "Analyze module dependency graph and detect cycles."
            exit 0 ;;
        *) shift ;;
    esac
done

cd "$PROJECT_ROOT" || exit 2

echo "=== Dependency Graph Analysis (Open-ClaudeCode) ===" >&2
echo "" >&2

# Collect dependencies as lines: "module|deps|deps|..."
# (bash 3.2 compatible — no associative arrays)
DEP_FILE="/tmp/deps-graph-$$.txt"
GRAPHS=""
ALL_NODES_FILE="/tmp/all-nodes-$$.txt"

> "$DEP_FILE"
> "$ALL_NODES_FILE"

# Scan for imports (TypeScript/TSX)
while IFS= read -r line; do
    [ -z "$line" ] && continue
    file=$(echo "$line" | cut -d: -f1)
    import_path=$(echo "$line" | sed -E "s/.*from ['\"]([^'\"]+)['\"].*/\1/" | sed -E "s/.*import\(['\"]([^'\"]+)['\"].*/\1/")

    # Resolve relative imports to module paths
    if [[ "$import_path" == .* ]]; then
        dir=$(dirname "$file")
        resolved=$(realpath --relative-to="$PROJECT_ROOT" "$dir/$import_path" 2>/dev/null || echo "")
        if [[ -n "$resolved" ]]; then
            module=$(echo "$resolved" | cut -d/ -f1-2)
            source_module=$(echo "$file" | cut -d/ -f1-2)

            if [[ "$module" != "$source_module" && "$module" == src/* ]]; then
                # Add node
                if ! grep -q "^${source_module}$" "$ALL_NODES_FILE" 2>/dev/null; then
                    echo "$source_module" >> "$ALL_NODES_FILE"
                fi
                if ! grep -q "^${module}$" "$ALL_NODES_FILE" 2>/dev/null; then
                    echo "$module" >> "$ALL_NODES_FILE"
                fi
                # Add edge
                if ! grep -q "^${source_module}|" "$DEP_FILE" 2>/dev/null; then
                    echo "${source_module}|${module}" >> "$DEP_FILE"
                elif ! grep "^${source_module}|" "$DEP_FILE" 2>/dev/null | grep -q "|${module}|"; then
                    sed -i '' "s/^${source_module}|/&${module}|/" "$DEP_FILE"
                fi
            fi
        fi
    fi
done < <(grep -rn "from ['\"].*\.\." src/ --include="*.ts" --include="*.tsx" 2>/dev/null | head -5000)

# DFS cycle detection (bash 3.2 compatible)
CYCLE_COUNT=0
CYCLES=""

dfs_node() {
    local node="$1"
    local path="$2"
    local depth="${3:-0}"

    # Mark as visited in stack
    echo "IN:$node" >> /tmp/dfs-stack-$$.txt

    # Get dependencies
    local deps=$(grep "^${node}|" "$DEP_FILE" 2>/dev/null | head -1 | sed "s/^${node}|//" | tr '|' '\n')
    [ -z "$deps" ] && deps=$(grep "^${node}|" "$DEP_FILE" 2>/dev/null | head -1 | cut -d'|' -f2-)

    for dep in $deps; do
        [ -z "$dep" ] && continue
        if grep -q "^IN:$dep$" /tmp/dfs-stack-$$.txt 2>/dev/null; then
            CYCLE_COUNT=$((CYCLE_COUNT + 1))
            CYCLES="${CYCLES}Cycle: $path -> $dep\n"
        elif ! grep -q "^DONE:$dep$" /tmp/dfs-stack-$$.txt 2>/dev/null; then
            CYCLES=$(dfs_node "$dep" "$path -> $dep" $((depth+1)))
            CYCLE_COUNT=$?
        fi
    done

    echo "DONE:$node" >> /tmp/dfs-stack-$$.txt
    return $CYCLE_COUNT
}

# Run DFS from all nodes
for node in $(cat "$ALL_NODES_FILE" 2>/dev/null); do
    [ -z "$node" ] && continue
    > /tmp/dfs-stack-$$.txt
    dfs_node "$node" "$node"
done

# Cleanup
rm -f /tmp/deps-graph-$$.txt /tmp/all-nodes-$$.txt /tmp/dfs-stack-$$.txt

# Count
MODULE_COUNT=$(cat "$ALL_NODES_FILE" 2>/dev/null | wc -l | tr -d ' ')
EDGE_COUNT=$(grep "" "$DEP_FILE" 2>/dev/null | wc -l | tr -d ' ')

echo "Project: Open-ClaudeCode (TypeScript CLI)" >&2
echo "Modules: ${MODULE_COUNT:-0}" >&2
echo "Edges: ${EDGE_COUNT:-0}" >&2
echo "Cycles: ${CYCLE_COUNT:-0}" >&2
echo "" >&2

if [[ ${CYCLE_COUNT:-0} -gt 0 ]]; then
    echo "Cycles detected:" >&2
    echo -e "$CYCLES" | head -20 >&2
    echo "" >&2
    echo "STATUS: FAIL ($CYCLE_COUNT cycles)" >&2
    exit 1
else
    echo "STATUS: PASS (no cycles detected)" >&2
    exit 0
fi
