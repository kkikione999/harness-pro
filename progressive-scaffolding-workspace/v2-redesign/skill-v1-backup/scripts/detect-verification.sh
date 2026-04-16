#!/bin/bash
# detect-verification.sh — Probe V1-V3 verification dimensions
# Output: V1:V2:V3 levels

PROJECT_ROOT="${1:-.}"

cd "$PROJECT_ROOT" || exit 1

echo "=== Verification Assessment ==="
echo ""

# V1: Exit Code — Can system report success/failure?
V1_LEVEL=1
if [ -f "Makefile" ] && grep -q "test" Makefile 2>/dev/null; then
    V1_LEVEL=2  # Tests return exit codes
fi
if [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
    V1_LEVEL=2
fi
if [ -f "go.mod" ]; then
    V1_LEVEL=2  # Go tests return exit codes
fi
if [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] && grep -q "pytest" pytest.ini pyproject.toml 2>/dev/null; then
    V1_LEVEL=3  # Has test framework
fi

# V2: Semantic — Can output be parsed?
V2_LEVEL=1
if [ -f "package.json" ] && grep -q '"test".*"--json"' package.json 2>/dev/null; then
    V2_LEVEL=3  # JSON output
fi
if [ -f "go.mod" ] && grep -q "test" go.mod 2>/dev/null; then
    V2_LEVEL=2  # Go test output is structured
fi
if grep -r "console.log.*JSON.stringify\|fmt.Printf.*%v\|print.*json" --include="*.go" --include="*.js" --include="*.py" . 2>/dev/null | head -3 | grep -q .; then
    V2_LEVEL=2  # Has structured output in code
fi

# V3: Automated — Can verification run without human?
V3_LEVEL=1
if [ -f ".github/workflows" ] || [ -d ".github/workflows" ]; then
    V3_LEVEL=3  # Has CI
fi
if [ -f "Makefile" ] && grep -q "ci\|lint\|test" Makefile 2>/dev/null; then
    V3_LEVEL=2  # Has make targets
fi
if [ -f "package.json" ] && grep -q '"lint\|"test\|"ci"' package.json 2>/dev/null; then
    V3_LEVEL=2
fi

echo "V1_EXIT_CODE: Level $V1_LEVEL"
echo "V2_SEMANTIC: Level $V2_LEVEL"
echo "V3_AUTOMATED: Level $V3_LEVEL"
echo ""

# Evidence
echo "Evidence:"
echo "- V1: $([ $V1_LEVEL -ge 2 ] && echo "Tests return exit codes" || echo "No exit code handling")"
echo "- V2: $([ $V2_LEVEL -ge 2 ] && echo "Has structured output" || echo "Raw text only")"
echo "- V3: $([ $V3_LEVEL -ge 2 ] && echo "Has automated verification" || echo "Manual verification only")"
echo ""

# Calculate total
TOTAL=$((V1_LEVEL + V2_LEVEL + V3_LEVEL))
MAX=9
echo "Verification Score: $TOTAL/$MAX"

# Exit code
[ $TOTAL -ge 6 ] && exit 0 || exit 1
