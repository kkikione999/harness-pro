#!/bin/bash
# scaffold/analyze-deps.sh
# Generates a dependency graph and detects circular imports.
# Uses static analysis of import statements to build a module-level graph.
# No external dependencies required (pure bash+grep).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
SRC_DIR="${PROJECT_ROOT}/src"
OUTPUT_DIR="${PROJECT_ROOT}/.scaffolding/deps"

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "=== Dependency Graph Analyzer ==="
echo "Source: ${SRC_DIR}"
echo "Output: ${OUTPUT_DIR}"
echo ""

# Mode selection
MODE="${1:-full}"
BASELINE_DIR="${OUTPUT_DIR}/baseline"

# Temp files for the graph
EDGES_FILE="${OUTPUT_DIR}/edges.raw"
NODES_FILE="${OUTPUT_DIR}/nodes.raw"
CYCLES_FILE="${OUTPUT_DIR}/cycles.txt"
GRAPH_DOT="${OUTPUT_DIR}/dep-graph.dot"
REPORT_FILE="${OUTPUT_DIR}/dep-report.txt"

# Initialize
: > "$EDGES_FILE"
: > "$NODES_FILE"

echo "Phase 1: Scanning imports and building edge list..."
SCANNED=0

# Build edges: for each file, extract what it imports
while IFS= read -r -d '' file; do
    # Get module name (directory under src/)
    relpath="${file#"$SRC_DIR/"}"
    # Normalize: group by top-level directory
    source_module="${relpath%%/*}"

    # Skip files directly in src/ root
    if [[ "$source_module" == "$(basename "$file")" ]]; then
        source_module="_root"
    fi

    # Record this node
    echo "$source_module" >> "$NODES_FILE"

    # Extract all imports
    while IFS= read -r import_path; do
        [[ -z "$import_path" ]] && continue

        target_module=""

        if [[ "$import_path" == src/* ]]; then
            target_module="${import_path#src/}"
            target_module="${target_module%%/*}"
        elif [[ "$import_path" == ./* ]] || [[ "$import_path" == ../* ]]; then
            file_dir=$(dirname "$file")
            resolved=$(cd "$file_dir" 2>/dev/null && realpath --relative-to="$SRC_DIR" "$import_path" 2>/dev/null || echo "")
            if [[ -n "$resolved" && "$resolved" != ".."* ]]; then
                target_module="${resolved%%/*}"
            fi
        fi

        # Skip external, self-referential, and empty
        [[ -z "$target_module" ]] && continue
        [[ "$target_module" == "$source_module" ]] && continue

        # Record edge
        echo "${source_module} -> ${target_module}" >> "$EDGES_FILE"

    done < <(grep -oE "from\s+['\"]([^'\"]+)['\"]" "$file" 2>/dev/null | sed "s/from\s*['\"]//;s/['\"]$//" || true)

    SCANNED=$((SCANNED + 1))

done < <(find "$SRC_DIR" -name "*.ts" -o -name "*.tsx" -print0 2>/dev/null)

echo "  Scanned ${SCANNED} files"

# Phase 2: Deduplicate edges and count
echo "Phase 2: Deduplicating edges..."
sort "$EDGES_FILE" | uniq -c | sort -rn > "${EDGES_FILE}.dedup"
TOTAL_EDGES=$(wc -l < "${EDGES_FILE}.dedup" | tr -d ' ')
echo "  Found ${TOTAL_EDGES} unique module-level edges"

# Phase 3: Get unique nodes
echo "Phase 3: Listing modules..."
sort "$NODES_FILE" | uniq | sort > "${NODES_FILE}.unique"
TOTAL_NODES=$(wc -l < "${NODES_FILE}.unique" | tr -d ' ')
echo "  Found ${TOTAL_NODES} modules"

# Phase 4: Detect cycles using DFS
echo "Phase 4: Detecting circular dependencies..."
: > "$CYCLES_FILE"

# Build adjacency list in a temp file
ADJ_FILE="${OUTPUT_DIR}/adjacency.txt"
: > "$ADJ_FILE"
while IFS= read -r line; do
    count=$(echo "$line" | awk '{print $1}')
    edge=$(echo "$line" | awk '{print $2 " " $3 " " $4}')
    src=$(echo "$edge" | awk '{print $1}')
    tgt=$(echo "$edge" | awk '{print $3}')
    echo "$src $tgt" >> "$ADJ_FILE"
done < "${EDGES_FILE}.dedup"

# Simple cycle detection: find mutual edges (A->B and B->A)
# For full cycle detection with arbitrary depth, we use a recursive approach
python3 - "${ADJ_FILE}" "$CYCLES_FILE" <<'PYEOF'
import sys
from collections import defaultdict

adj_file = sys.argv[1]
cycles_file = sys.argv[2]

# Build adjacency list
graph = defaultdict(set)
with open(adj_file) as f:
    for line in f:
        parts = line.strip().split()
        if len(parts) == 2:
            graph[parts[0]].add(parts[1])

# Find cycles using DFS
cycles = []
visited = set()
rec_stack = set()
path = []

def dfs(node):
    visited.add(node)
    rec_stack.add(node)
    path.append(node)

    for neighbor in graph.get(node, set()):
        if neighbor not in visited:
            cycle = dfs(neighbor)
            if cycle:
                return cycle
        elif neighbor in rec_stack:
            # Found a cycle
            cycle_start = path.index(neighbor)
            cycle = path[cycle_start:] + [neighbor]
            cycles.append(cycle)

    path.pop()
    rec_stack.discard(node)
    return None

for node in sorted(graph.keys()):
    if node not in visited:
        dfs(node)

# Write cycles to file
with open(cycles_file, 'w') as f:
    if cycles:
        f.write(f"FOUND {len(cycles)} CYCLE(S):\n\n")
        for i, cycle in enumerate(cycles, 1):
            f.write(f"Cycle {i}: {' -> '.join(cycle)}\n")
    else:
        f.write("NO CYCLES FOUND\n")

    # Also write module fan-out stats
    f.write(f"\n--- Module Fan-Out (top 15) ---\n")
    fanout = [(node, len(targets)) for node, targets in graph.items()]
    fanout.sort(key=lambda x: -x[1])
    for node, count in fanout[:15]:
        f.write(f"  {node}: {count} dependencies\n")

    f.write(f"\n--- Module Fan-In (top 15) ---\n")
    fanin = defaultdict(int)
    for node, targets in graph.items():
        for t in targets:
            fanin[t] += 1
    fanin_list = sorted(fanin.items(), key=lambda x: -x[1])
    for node, count in fanin_list[:15]:
        f.write(f"  {node}: imported by {count} modules\n")

PYEOF

echo ""
cat "$CYCLES_FILE"

# Phase 5: Generate DOT graph
echo ""
echo "Phase 5: Generating DOT graph..."
{
    echo "digraph dependencies {"
    echo "  rankdir=LR;"
    echo "  node [shape=box, fontsize=10];"
    echo ""

    # Add edges with weights
    while IFS= read -r line; do
        count=$(echo "$line" | awk '{print $1}')
        edge=$(echo "$line" | awk '{print $2 " " $3 " " $4}')
        src=$(echo "$edge" | awk '{print $1}')
        tgt=$(echo "$edge" | awk '{print $3}')
        # Scale penwidth by count
        pw=$(echo "scale=1; $count / 50 + 0.5" | bc 2>/dev/null || echo "1")
        echo "  \"$src\" -> \"$tgt\" [penwidth=$pw, weight=$count];"
    done < "${EDGES_FILE}.dedup"

    echo ""
    echo "}"
} > "$GRAPH_DOT"

echo "  DOT graph written to: $GRAPH_DOT"

# Phase 6: Compare with baseline if it exists
if [[ "$MODE" == "compare" ]] && [[ -f "${BASELINE_DIR}/edges.raw.dedup" ]]; then
    echo ""
    echo "Phase 6: Comparing with baseline..."
    NEW_EDGES=$(comm -23 <(sort "${EDGES_FILE}.dedup") <(sort "${BASELINE_DIR}/edges.raw.dedup") | wc -l | tr -d ' ')
    REMOVED_EDGES=$(comm -13 <(sort "${EDGES_FILE}.dedup") <(sort "${BASELINE_DIR}/edges.raw.dedup") | wc -l | tr -d ' ')
    echo "  New edges since baseline: $NEW_EDGES"
    echo "  Removed edges since baseline: $REMOVED_EDGES"
fi

# Summary
echo ""
echo "=== Dependency Analysis Summary ==="
echo "Modules: ${TOTAL_NODES}"
echo "Unique edges: ${TOTAL_EDGES}"
echo "Cycles: $(grep -c "^Cycle" "$CYCLES_FILE" 2>/dev/null || echo "0")"
echo ""
echo "Artifacts:"
echo "  Graph (DOT): ${GRAPH_DOT}"
echo "  Cycles: ${CYCLES_FILE}"
echo "  Edges: ${EDGES_FILE}.dedup"
echo ""
echo "To visualize the graph: dot -Tpng ${GRAPH_DOT} -o dep-graph.png"
echo "To set baseline: cp -r ${OUTPUT_DIR} ${BASELINE_DIR}"

exit 0
