#!/bin/bash
# scaffold/scaffold-all.sh
# Master scaffolding runner: sets up both controllability and observability.
# Usage: bash scaffold-all.sh [--controllability|--observability]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

MODE="${1:-all}"

echo "========================================="
echo "   Open-ClaudeCode Scaffolding"
echo "========================================="
echo "Project: ${PROJECT_ROOT}"
echo "Mode: ${MODE}"
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Create scaffolding directory structure
mkdir -p "${PROJECT_ROOT}/.scaffolding"
mkdir -p "${PROJECT_ROOT}/.scaffolding/gates"
mkdir -p "${PROJECT_ROOT}/.scaffolding/deps"
mkdir -p "${PROJECT_ROOT}/.scaffolding/observability"
mkdir -p "${PROJECT_ROOT}/.scaffolding/reports"

# Make all scripts executable
find "${SCRIPT_DIR}" -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true

case "$MODE" in
    --controllability)
        echo "Running controllability scaffolding only..."
        bash "${SCRIPT_DIR}/scaffold-controllability.sh"
        ;;
    --observability)
        echo "Running observability scaffolding only..."
        bash "${SCRIPT_DIR}/scaffold-observability.sh"
        ;;
    all|"")
        echo "Running full scaffolding..."
        echo ""
        echo "=== Phase 1: Controllability ==="
        echo ""
        bash "${SCRIPT_DIR}/scaffold-controllability.sh" || true
        echo ""
        echo "=== Phase 2: Observability ==="
        echo ""
        bash "${SCRIPT_DIR}/scaffold-observability.sh" || true
        ;;
    *)
        echo "Unknown mode: ${MODE}"
        echo "Usage: bash scaffold-all.sh [--controllability|--observability]"
        exit 1
        ;;
esac

echo ""
echo "========================================="
echo "   Scaffolding Complete"
echo "========================================="
echo ""
echo "Next steps:"
echo "  1. Review reports in .scaffolding/reports/"
echo "  2. Review instrumentation plans in .scaffolding/observability/"
echo "  3. Run 'bash run-all-gates.sh' to verify all gates pass"
echo "  4. Consider integrating ci-pipeline.yml into GitHub Actions"

exit 0
