#!/bin/bash
# detect-controllability.sh — Probe E1-E4 controllability dimensions
# Output: E1:E2:E3:E4 levels

PROJECT_ROOT="${1:-.}"

cd "$PROJECT_ROOT" || exit 1

echo "=== Controllability Assessment ==="
echo ""

# E1: Execute — Can agent trigger code execution?
E1_LEVEL=1
if [ -f "Makefile" ]; then
    if grep -q "run\|serve\|start\|test" Makefile 2>/dev/null; then
        E1_LEVEL=2
    fi
fi
if [ -f "package.json" ] && grep -q '"scripts"' package.json 2>/dev/null; then
    E1_LEVEL=2
fi
if [ -f "go.mod" ]; then
    E1_LEVEL=2
fi
if [ -f "docker-compose.yml" ] || [ -f "Dockerfile" ]; then
    E1_LEVEL=3
fi

# E2: Intervene — Can agent modify system state?
E2_LEVEL=1
if [ -w "." ]; then
    E2_LEVEL=2  # Can write files
fi
if [ -f "docker-compose.yml" ] || [ -f "Dockerfile" ]; then
    E2_LEVEL=3  # Can rebuild environment
fi
if pgrep -f "node\|python\|go run" > /dev/null 2>&1; then
    E2_LEVEL=3  # Can manage processes
fi

# E3: Input — Can agent inject data into system?
E3_LEVEL=1
if [ -f ".env" ] || [ -f ".env.example" ]; then
    E3_LEVEL=2  # Has env file
fi
if grep -q "process.env\|os.environ\|getenv" *.* 2>/dev/null | head -1; then
    E3_LEVEL=2  # Uses environment variables
fi
if [ -f "config.yaml" ] || [ -f "config.json" ]; then
    E3_LEVEL=3  # Has structured config
fi

# E4: Orchestrate — Can agent execute multi-step flows?
E4_LEVEL=1
if [ -f "Makefile" ] && grep -q ".*&&.*\|.*|.*" Makefile 2>/dev/null; then
    E4_LEVEL=2  # Has chained commands
fi
if [ -f "docker-compose.yml" ]; then
    E4_LEVEL=3  # Has compose for orchestration
fi
if [ -f "package.json" ] && grep -q '"scripts"' package.json 2>/dev/null; then
    E4_LEVEL=2
fi

echo "E1_EXECUTE: Level $E1_LEVEL"
echo "E2_INTERVENE: Level $E2_LEVEL"
echo "E3_INPUT: Level $E3_LEVEL"
echo "E4_ORCHESTRATE: Level $E4_LEVEL"
echo ""

# Evidence
echo "Evidence:"
echo "- E1: $([ $E1_LEVEL -ge 2 ] && echo "Build system found" || echo "Only bash available")"
echo "- E2: $([ $E2_LEVEL -ge 2 ] && echo "Can modify state" || echo "Read-only access")"
echo "- E3: $([ $E3_LEVEL -ge 2 ] && echo "Has config injection" || echo "No injection mechanism")"
echo "- E4: $([ $E4_LEVEL -ge 2 ] && echo "Has orchestration" || echo "Manual multi-step")"
echo ""

# Calculate total
TOTAL=$((E1_LEVEL + E2_LEVEL + E3_LEVEL + E4_LEVEL))
MAX=12
echo "Controllability Score: $TOTAL/$MAX"

# Exit code
[ $TOTAL -ge 8 ] && exit 0 || exit 1
