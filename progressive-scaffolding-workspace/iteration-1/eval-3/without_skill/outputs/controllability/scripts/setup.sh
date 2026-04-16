#!/bin/bash
# Setup script for harness-blogs

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../../../.." && pwd)"

echo "=== harness-blogs Setup ==="
echo ""

echo "Project root: $PROJECT_ROOT"
echo ""

echo "--- Checking Prerequisites ---"
prereq_passed=true

# Check for required tools
for tool in bash grep sed awk; do
    if command -v "$tool" &> /dev/null; then
        echo "  [OK] $tool"
    else
        echo "  [MISSING] $tool"
        prereq_passed=false
    fi
done

echo ""
if [ "$prereq_passed" = true ]; then
    echo "All prerequisites met"
else
    echo "Some prerequisites missing"
    exit 1
fi

echo ""
echo "--- Setting Up Directory Structure ---"

# Ensure output directories exist
mkdir -p "$PROJECT_ROOT/generated-docs"
echo "  Created: generated-docs/"

mkdir -p "$PROJECT_ROOT/.cache"
echo "  Created: .cache/"

echo ""
echo "--- Verifying Project Structure ---"
verify_passed=true

if [ -f "$PROJECT_ROOT/HARNESS-ENGINEERING-IMPLEMENTATION-GUIDE.md" ]; then
    echo "  [OK] Main documentation present"
else
    echo "  [WARN] Main documentation missing"
    verify_passed=false
fi

if [ -d "$PROJECT_ROOT/progressive-scaffolding-workspace/iteration-1/eval-3/without_skill/outputs" ]; then
    echo "  [OK] Outputs directory exists"
else
    echo "  [WARN] Outputs directory missing"
fi

echo ""
echo "=== Setup Complete ==="