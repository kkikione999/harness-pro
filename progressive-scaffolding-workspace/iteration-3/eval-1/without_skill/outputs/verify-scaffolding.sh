#!/bin/bash
# scaffold/verify-scaffolding.sh
# Verifies that all scaffolding is correctly installed and operational.
# Run this after scaffold-all.sh to confirm everything works.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo "========================================="
echo "   Scaffolding Verification"
echo "========================================="
echo ""

CHECKS_TOTAL=0
CHECKS_PASS=0
CHECKS_FAIL=0

check() {
    local description="$1"
    local condition="$2"

    CHECKS_TOTAL=$((CHECKS_TOTAL + 1))

    if eval "$condition"; then
        echo -e "  ${GREEN}[PASS]${NC} ${description}"
        CHECKS_PASS=$((CHECKS_PASS + 1))
    else
        echo -e "  ${RED}[FAIL]${NC} ${description}"
        CHECKS_FAIL=$((CHECKS_FAIL + 1))
    fi
}

# Check 1: Script files exist
echo "--- Controllability Scripts ---"
check "lint-import-direction.sh exists" "[[ -f '${SCRIPT_DIR}/lint-import-direction.sh' ]]"
check "lint-export-counts.sh exists" "[[ -f '${SCRIPT_DIR}/lint-export-counts.sh' ]]"
check "analyze-deps.sh exists" "[[ -f '${SCRIPT_DIR}/analyze-deps.sh' ]]"
check "validate-tool-signatures.sh exists" "[[ -f '${SCRIPT_DIR}/validate-tool-signatures.sh' ]]"
check "run-all-gates.sh exists" "[[ -f '${SCRIPT_DIR}/run-all-gates.sh' ]]"
check "scaffold-controllability.sh exists" "[[ -f '${SCRIPT_DIR}/scaffold-controllability.sh' ]]"
echo ""

echo "--- Observability Scripts ---"
check "instrument-tool-lifecycle.sh exists" "[[ -f '${SCRIPT_DIR}/instrument-tool-lifecycle.sh' ]]"
check "trace-query-pipeline.sh exists" "[[ -f '${SCRIPT_DIR}/trace-query-pipeline.sh' ]]"
check "audit-state-mutations.sh exists" "[[ -f '${SCRIPT_DIR}/audit-state-mutations.sh' ]]"
check "collect-metrics.sh exists" "[[ -f '${SCRIPT_DIR}/collect-metrics.sh' ]]"
check "scaffold-observability.sh exists" "[[ -f '${SCRIPT_DIR}/scaffold-observability.sh' ]]"
echo ""

echo "--- Master Scripts ---"
check "scaffold-all.sh exists" "[[ -f '${SCRIPT_DIR}/scaffold-all.sh' ]]"
check "verify-scaffolding.sh exists" "[[ -f '${SCRIPT_DIR}/verify-scaffolding.sh' ]]"
check "ci-pipeline.yml exists" "[[ -f '${SCRIPT_DIR}/ci-pipeline.yml' ]]"
echo ""

# Check 2: Scripts are executable
echo "--- Permissions ---"
for script in lint-import-direction.sh lint-export-counts.sh analyze-deps.sh validate-tool-signatures.sh run-all-gates.sh; do
    check "${script} is executable" "[[ -x '${SCRIPT_DIR}/${script}' ]]"
done
echo ""

# Check 3: Existing GP linters
echo "--- Existing Infrastructure ---"
check "rules/scripts/check.py exists" "[[ -f '${PROJECT_ROOT}/rules/scripts/check.py' ]]"
check "rules/_registry.json exists" "[[ -f '${PROJECT_ROOT}/rules/_registry.json' ]]"
check "rules/scripts/ has GP linters" "[[ \$(ls '${PROJECT_ROOT}/rules/scripts/'lint-gp*.sh 2>/dev/null | wc -l) -ge 8 ]]"
echo ""

# Check 4: Source code structure
echo "--- Source Code ---"
check "src/ directory exists" "[[ -d '${PROJECT_ROOT}/src' ]]"
check "src/tools/ directory exists" "[[ -d '${PROJECT_ROOT}/src/tools' ]]"
check "src/state/ directory exists" "[[ -d '${PROJECT_ROOT}/src/state' ]]"
check "src/QueryEngine.ts exists" "[[ -f '${PROJECT_ROOT}/src/QueryEngine.ts' ]]"
check "src/cost-tracker.ts exists" "[[ -f '${PROJECT_ROOT}/src/cost-tracker.ts' ]]"
echo ""

# Check 5: Scripts produce valid output (dry run)
echo "--- Dry Run Validation ---"
check "lint-import-direction.sh runs without errors" "bash '${SCRIPT_DIR}/lint-import-direction.sh' >/dev/null 2>&1"
check "validate-tool-signatures.sh runs without errors" "bash '${SCRIPT_DIR}/validate-tool-signatures.sh' >/dev/null 2>&1"
check "collect-metrics.sh runs without errors" "bash '${SCRIPT_DIR}/collect-metrics.sh' >/dev/null 2>&1"
echo ""

# Check 6: Assessment report
echo "--- Documentation ---"
check "ASSESSMENT-REPORT.md exists" "[[ -f '${SCRIPT_DIR}/ASSESSMENT-REPORT.md' ]]"
echo ""

# Summary
echo "========================================="
echo "   Verification Summary"
echo "========================================="
echo "Total checks: ${CHECKS_TOTAL}"
echo -e "Passed: ${GREEN}${CHECKS_PASS}${NC}"
echo -e "Failed: ${RED}${CHECKS_FAIL}${NC}"
echo ""

if [[ $CHECKS_FAIL -gt 0 ]]; then
    echo -e "${RED}VERIFICATION FAILED: ${CHECKS_FAIL} check(s) did not pass${NC}"
    exit 1
else
    echo -e "${GREEN}VERIFICATION PASSED: All scaffolding checks passed${NC}"
    exit 0
fi
