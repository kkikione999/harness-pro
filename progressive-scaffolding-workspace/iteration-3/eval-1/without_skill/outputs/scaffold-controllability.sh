#!/bin/bash
# scaffold/scaffold-controllability.sh
# Master controllability scaffolding runner.
# Sets up all controllability infrastructure for Open-ClaudeCode.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

echo "========================================="
echo "   Controllability Scaffolding Setup"
echo "========================================="
echo "Project: ${PROJECT_ROOT}"
echo ""

SCAFFOLD_DIR="${PROJECT_ROOT}/.scaffolding"
mkdir -p "${SCAFFOLD_DIR}/gates"
mkdir -p "${SCAFFOLD_DIR}/deps"
mkdir -p "${SCAFFOLD_DIR}/reports"

# Step 1: Make all scripts executable
echo "[1/5] Setting script permissions..."
chmod +x "${SCRIPT_DIR}/lint-import-direction.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/lint-export-counts.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/analyze-deps.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/validate-tool-signatures.sh" 2>/dev/null || true
chmod +x "${SCRIPT_DIR}/run-all-gates.sh" 2>/dev/null || true
echo "  Done"
echo ""

# Step 2: Run existing Golden Principle linters
echo "[2/5] Running existing Golden Principle linters..."
if [[ -f "${PROJECT_ROOT}/rules/scripts/check.py" ]]; then
    python3 "${PROJECT_ROOT}/rules/scripts/check.py" --verbose 2>&1 | tee "${SCAFFOLD_DIR}/reports/gp-lint-results.txt" || true
else
    echo "  WARNING: rules/scripts/check.py not found, skipping GP linters"
fi
echo ""

# Step 3: Run import direction analysis
echo "[3/5] Running import direction analysis..."
if [[ -f "${SCRIPT_DIR}/lint-import-direction.sh" ]]; then
    bash "${SCRIPT_DIR}/lint-import-direction.sh" 2>&1 | tee "${SCAFFOLD_DIR}/reports/import-direction-results.txt" || true
fi
echo ""

# Step 4: Run dependency analysis
echo "[4/5] Running dependency analysis..."
if [[ -f "${SCRIPT_DIR}/analyze-deps.sh" ]]; then
    bash "${SCRIPT_DIR}/analyze-deps.sh" 2>&1 | tee "${SCAFFOLD_DIR}/reports/deps-analysis-results.txt" || true
fi
echo ""

# Step 5: Run tool signature validation
echo "[5/5] Running tool signature validation..."
if [[ -f "${SCRIPT_DIR}/validate-tool-signatures.sh" ]]; then
    bash "${SCRIPT_DIR}/validate-tool-signatures.sh" 2>&1 | tee "${SCAFFOLD_DIR}/reports/tool-signatures-results.txt" || true
fi
echo ""

echo "========================================="
echo "   Controllability Scaffolding Complete"
echo "========================================="
echo ""
echo "Artifacts generated in: ${SCAFFOLD_DIR}/"
echo ""
echo "Available gates:"
echo "  run-all-gates.sh           - Run all controllability gates"
echo "  lint-import-direction.sh   - Check module layer dependency direction"
echo "  lint-export-counts.sh      - Detect potential dead code"
echo "  analyze-deps.sh            - Dependency graph + cycle detection"
echo "  validate-tool-signatures.sh - Validate tool call() patterns"
echo ""
echo "Reports in: ${SCAFFOLD_DIR}/reports/"
ls "${SCAFFOLD_DIR}/reports/" 2>/dev/null | sed 's/^/  /'

exit 0
