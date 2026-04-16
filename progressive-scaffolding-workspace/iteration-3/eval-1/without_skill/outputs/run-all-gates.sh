#!/bin/bash
# scaffold/run-all-gates.sh
# Master gate runner: executes all controllability checks and produces a summary.
# Exit code: 0 if all gates pass, 1 if any gate fails.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
RULES_DIR="${PROJECT_ROOT}/rules"
SCAFFOLD_DIR="${SCRIPT_DIR}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo "========================================="
echo "   Open-ClaudeCode Controllability Gates"
echo "========================================="
echo "Project: ${PROJECT_ROOT}"
echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
echo ""

# Gate results storage
declare -a GATE_NAMES=()
declare -a GATE_RESULTS=()
declare -a GATE_OUTPUTS=()

# Run a gate and capture result
run_gate() {
    local name="$1"
    local script="$2"
    shift 2
    local args=("$@")

    echo "--- Running: ${name} ---"

    local output
    local exit_code=0
    output=$(bash "$script" "${args[@]}" 2>&1) || exit_code=$?

    GATE_NAMES+=("$name")
    GATE_OUTPUTS+=("$output")

    if [[ $exit_code -eq 0 ]]; then
        if echo "$output" | grep -qi "warning"; then
            GATE_RESULTS+=("WARN")
            echo -e "  ${YELLOW}WARN${NC}"
        else
            GATE_RESULTS+=("PASS")
            echo -e "  ${GREEN}PASS${NC}"
        fi
    else
        GATE_RESULTS+=("FAIL")
        echo -e "  ${RED}FAIL${NC}"
    fi

    # Show last 3 lines of output as summary
    echo "$output" | tail -3 | sed 's/^/    /'
    echo ""
}

# Gate 1: Golden Principle linters (existing)
if [[ -f "${RULES_DIR}/scripts/check.py" ]]; then
    echo "--- Running: Golden Principles (GP-001 through GP-008) ---"
    gp_output=$(python3 "${RULES_DIR}/scripts/check.py" 2>&1) || true
    GATE_NAMES+=("Golden Principles")
    GATE_OUTPUTS+=("$gp_output")
    if echo "$gp_output" | grep -q "PASSED"; then
        GATE_RESULTS+=("PASS")
        echo -e "  ${GREEN}PASS${NC}"
    else
        GATE_RESULTS+=("FAIL")
        echo -e "  ${RED}FAIL${NC}"
    fi
    echo "$gp_output" | tail -5 | sed 's/^/    /'
    echo ""
fi

# Gate 2: Import direction
if [[ -f "${SCAFFOLD_DIR}/lint-import-direction.sh" ]]; then
    run_gate "Import Direction" "${SCAFFOLD_DIR}/lint-import-direction.sh"
fi

# Gate 3: Export/Import ratio
if [[ -f "${SCAFFOLD_DIR}/lint-export-counts.sh" ]]; then
    run_gate "Export/Import Ratio" "${SCAFFOLD_DIR}/lint-export-counts.sh"
fi

# Gate 4: Dependency analysis (cycles only)
if [[ -f "${SCAFFOLD_DIR}/analyze-deps.sh" ]]; then
    echo "--- Running: Dependency Cycles ---"
    dep_output=$(bash "${SCAFFOLD_DIR}/analyze-deps.sh" 2>&1) || true
    GATE_NAMES+=("Dependency Cycles")
    GATE_OUTPUTS+=("$dep_output")
    if echo "$dep_output" | grep -q "NO CYCLES FOUND"; then
        GATE_RESULTS+=("PASS")
        echo -e "  ${GREEN}PASS${NC}"
    else
        cycle_count=$(echo "$dep_output" | grep -c "^Cycle " || echo "0")
        if [[ "$cycle_count" -gt 0 ]]; then
            GATE_RESULTS+=("FAIL")
            echo -e "  ${RED}FAIL${NC}"
        else
            GATE_RESULTS+=("PASS")
            echo -e "  ${GREEN}PASS${NC}"
        fi
    fi
    echo "$dep_output" | tail -5 | sed 's/^/    /'
    echo ""
fi

# Gate 5: Tool signatures
if [[ -f "${SCAFFOLD_DIR}/validate-tool-signatures.sh" ]]; then
    run_gate "Tool Signatures" "${SCAFFOLD_DIR}/validate-tool-signatures.sh"
fi

# Summary
echo "========================================="
echo "   Gate Summary"
echo "========================================="

TOTAL=${#GATE_NAMES[@]}
PASSED=0
FAILED=0
WARNED=0

for i in "${!GATE_NAMES[@]}"; do
    name="${GATE_NAMES[$i]}"
    result="${GATE_RESULTS[$i]}"

    case "$result" in
        PASS)
            echo -e "  ${GREEN}[PASS]${NC} ${name}"
            PASSED=$((PASSED + 1))
            ;;
        WARN)
            echo -e "  ${YELLOW}[WARN]${NC} ${name}"
            WARNED=$((WARNED + 1))
            PASSED=$((PASSED + 1))
            ;;
        FAIL)
            echo -e "  ${RED}[FAIL]${NC} ${name}"
            FAILED=$((FAILED + 1))
            ;;
    esac
done

echo ""
echo "Total: ${TOTAL} gates | ${PASSED} passed | ${FAILED} failed | ${WARNED} warned"

# Write report to file
REPORT_FILE="${PROJECT_ROOT}/.scaffolding/gate-report.txt"
mkdir -p "$(dirname "$REPORT_FILE")"
{
    echo "Open-ClaudeCode Controllability Gate Report"
    echo "Date: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "============================================"
    echo ""
    for i in "${!GATE_NAMES[@]}"; do
        echo "--- ${GATE_NAMES[$i]}: ${GATE_RESULTS[$i]} ---"
        echo "${GATE_OUTPUTS[$i]}"
        echo ""
    done
    echo "============================================"
    echo "Summary: ${PASSED} passed, ${FAILED} failed, ${WARNED} warned"
} > "$REPORT_FILE"

echo "Full report: ${REPORT_FILE}"

if [[ $FAILED -gt 0 ]]; then
    echo ""
    echo -e "${RED}FAILED: ${FAILED} gate(s) did not pass${NC}"
    exit 1
else
    echo ""
    echo -e "${GREEN}PASSED: All controllability gates passed${NC}"
    exit 0
fi
