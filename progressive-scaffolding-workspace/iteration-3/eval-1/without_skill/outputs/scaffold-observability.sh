#!/bin/bash
# scaffold/scaffold-observability.sh
# Master observability scaffolding runner.
# Sets up all observability infrastructure for Open-ClaudeCode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

echo "========================================="
echo "   Observability Scaffolding Setup"
echo "========================================="
echo "Project: ${PROJECT_ROOT}"
echo ""

SCAFFOLD_DIR="${PROJECT_ROOT}/.scaffolding"
mkdir -p "${SCAFFOLD_DIR}/observability"

# Step 1: Make scripts executable
echo "[1/4] Setting script permissions..."
chmod +x "${SCRIPT_DIR}/instrument-tool-lifecycle.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/trace-query-pipeline.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/audit-state-mutations.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/collect-metrics.sh" 2>/dev/null || true
echo "  Done"
echo ""

# Step 2: Analyze tool lifecycle
echo "[2/4] Analyzing tool lifecycle instrumentation..."
if [[ -f "${SCRIPT_DIR}/instrument-tool-lifecycle.sh" ]]; then
    bash "${SCRIPT_DIR}/instrument-tool-lifecycle.sh" 2>&1 | tee "${SCAFFOLD_DIR}/observability/tool-lifecycle-output.txt" || true
fi
echo ""

# Step 3: Analyze query pipeline tracing
echo "[3/4] Analyzing query pipeline tracing..."
if [[ -f "${SCRIPT_DIR}/trace-query-pipeline.sh" ]]; then
    bash "${SCRIPT_DIR}/trace-query-pipeline.sh" 2>&1 | tee "${SCAFFOLD_DIR}/observability/pipeline-trace-output.txt" || true
fi
echo ""

# Step 4: Analyze state mutations
echo "[4/4] Analyzing state mutation audit..."
if [[ -f "${SCRIPT_DIR}/audit-state-mutations.sh" ]]; then
    bash "${SCRIPT_DIR}/audit-state-mutations.sh" 2>&1 | tee "${SCAFFOLD_DIR}/observability/state-audit-output.txt" || true
fi
echo ""

# Step 5: Collect metrics catalog
echo "[5/5] Collecting metrics catalog..."
if [[ -f "${SCRIPT_DIR}/collect-metrics.sh" ]]; then
    bash "${SCRIPT_DIR}/collect-metrics.sh" 2>&1 | tee "${SCAFFOLD_DIR}/observability/metrics-catalog-output.txt" || true
fi
echo ""

echo "========================================="
echo "   Observability Scaffolding Complete"
echo "========================================="
echo ""
echo "Templates generated in: ${SCAFFOLD_DIR}/observability/"
echo ""
echo "Available templates:"
ls "${SCAFFOLD_DIR}/observability/"*-template.ts 2>/dev/null | sed 's/^/  /' || echo "  (templates will be generated on first run)"
echo ""
echo "Available scripts:"
echo "  instrument-tool-lifecycle.sh  - Generate tool lifecycle instrumentation plan"
echo "  trace-query-pipeline.sh       - Generate pipeline tracing plan"
echo "  audit-state-mutations.sh      - Generate state mutation audit plan"
echo "  collect-metrics.sh            - Generate metrics catalog"

exit 0
