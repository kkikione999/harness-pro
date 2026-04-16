#!/bin/bash
# health.sh - Health check script for harness-blogs

set -e

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HARNESS_DIR/.." && pwd)"

CORRELATION_ID="health-$$-$(date +%Y%m%d-%H%M%S)"

echo "=== Health Check ==="
echo "Correlation ID: $CORRELATION_ID"
echo "Timestamp: $(date -Iseconds)"
echo ""

HEALTHY=true
declare -a HEALTH_CHECKS

# Check 1: Project root exists and is readable
echo "[1/4] Project integrity..."
if [ -r "$PROJECT_ROOT" ] && [ -d "$PROJECT_ROOT" ]; then
    HEALTH_CHECKS+=("{\"check\": \"project_integrity\", \"status\": \"PASS\", \"message\": \"Project root accessible\"}")
    echo "  ✓ PASS"
else
    HEALTHY=false
    HEALTH_CHECKS+=("{\"check\": \"project_integrity\", \"status\": \"FAIL\", \"message\": \"Project root not accessible\"}")
    echo "  ✗ FAIL"
fi

# Check 2: Core files exist
echo "[2/4] Core documentation..."
CORE_FILES=(
    "HARNESS-ENGINEERING-IMPLEMENTATION-GUIDE.md"
    "PROGRESSIVE-RULES-DESIGN.md"
)
ALL_CORE_EXIST=true
for file in "${CORE_FILES[@]}"; do
    if [ ! -f "$PROJECT_ROOT/$file" ]; then
        ALL_CORE_EXIST=false
        break
    fi
done

if [ "$ALL_CORE_EXIST" = true ]; then
    HEALTH_CHECKS+=("{\"check\": \"core_documentation\", \"status\": \"PASS\", \"message\": \"All core files present\"}")
    echo "  ✓ PASS"
else
    HEALTHY=false
    HEALTH_CHECKS+=("{\"check\": \"core_documentation\", \"status\": \"FAIL\", \"message\": \"Missing core files\"}")
    echo "  ✗ FAIL"
fi

# Check 3: Directory structure
echo "[3/4] Directory structure..."
if [ -d "$PROJECT_ROOT/progressive-rules-workspace" ] || [ -d "$PROJECT_ROOT/progressive-scaffolding-workspace" ]; then
    HEALTH_CHECKS+=("{\"check\": \"workspace_structure\", \"status\": \"PASS\", \"message\": \"Workspace directories present\"}")
    echo "  ✓ PASS"
else
    HEALTH_CHECKS+=("{\"check\": \"workspace_structure\", \"status\": \"WARN\", \"message\": \"No workspace directories\"}")
    echo "  ⚠ WARN"
fi

# Check 4: Harness scaffolding
echo "[4/4] Harness scaffolding..."
if [ -d "$PROJECT_ROOT/.harness" ] || [ -d "$HARNESS_DIR" ]; then
    HEALTH_CHECKS+=("{\"check\": \"harness_scaffolding\", \"status\": \"PASS\", \"message\": \"Harness scaffolding present\"}")
    echo "  ✓ PASS"
else
    HEALTH_CHECKS+=("{\"check\": \"harness_scaffolding\", \"status\": \"WARN\", \"message\": \"No harness scaffolding found\"}")
    echo "  ⚠ WARN"
fi

# Output JSON for machine parsing
echo ""
echo "=== Machine-Readable Output ==="
printf '%s\n' '{"correlation_id": "'$CORRELATION_ID'", "timestamp": "'$(date -Iseconds)'", "overall_status": "'$([ "$HEALTHY" = true ] && echo "HEALTHY" || echo "UNHEALTHY")'", "checks": ['
FIRST=true
for check in "${HEALTH_CHECKS[@]}"; do
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        printf ','
    fi
    printf '%s' "$check"
done
printf '\n]}'

echo ""
echo "Overall Status: $([ "$HEALTHY" = true ] && echo "HEALTHY" || echo "UNHEALTHY")"

if [ "$HEALTHY" = true ]; then
    exit 0
else
    exit 1
fi
