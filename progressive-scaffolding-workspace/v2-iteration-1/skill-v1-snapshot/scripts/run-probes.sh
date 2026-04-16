#!/bin/bash
# run-probes.sh — Run all probes and produce assessment report
# Usage: ./run-probes.sh /path/to/project

PROJECT_ROOT="${1:-.}"

echo "========================================"
echo "  Progressive Scaffolding Assessment"
echo "  Project: $PROJECT_ROOT"
echo "========================================"
echo ""

# Step 1: Detect project type
echo "[1/5] Detecting project type..."
PROJECT_TYPE=$(./detect-project-type.sh "$PROJECT_ROOT" 2>/dev/null | grep "^Type:" | awk '{print $2}')
if [ -z "$PROJECT_TYPE" ]; then
    PROJECT_TYPE=$(./detect-project-type.sh "$PROJECT_ROOT" 2>&1 | tail -1)
fi
echo "Project type: $PROJECT_TYPE"
echo ""

# Step 2: Run controllability probes
echo "[2/5] Assessing controllability..."
CONTROLLABILITY=$(./detect-controllability.sh "$PROJECT_ROOT" 2>&1)
echo "$CONTROLLABILITY"
echo ""

# Step 3: Run observability probes
echo "[3/5] Assessing observability..."
OBSERVABILITY=$(./detect-observability.sh "$PROJECT_ROOT" 2>&1)
echo "$OBSERVABILITY"
echo ""

# Step 4: Run verification probes
echo "[4/5] Assessing verification..."
VERIFICATION=$(./detect-verification.sh "$PROJECT_ROOT" 2>&1)
echo "$VERIFICATION"
echo ""

# Step 5: Calculate overall scores
echo "[5/5] Calculating overall scores..."
echo ""
echo "========================================"
echo "  Assessment Complete"
echo "========================================"

# Extract scores
E_SCORE=$(echo "$CONTROLLABILITY" | grep "Controllability Score:" | grep -oP '\d+/\d+')
O_SCORE=$(echo "$OBSERVABILITY" | grep "Observability Score:" | grep -oP '\d+/\d+')
V_SCORE=$(echo "$VERIFICATION" | grep "Verification Score:" | grep -oP '\d+/\d+')

echo "Controllability: $E_SCORE"
echo "Observability:   $O_SCORE"
echo "Verification:    $V_SCORE"
echo ""

# Determine overall usability
E_NUM=$(echo $E_SCORE | cut -d/ -f1)
O_NUM=$(echo $O_SCORE | cut -d/ -f1)
V_NUM=$(echo $V_SCORE | cut -d/ -f1)

USABLE=true
if [ "$E_NUM" -lt 8 ] || [ "$O_NUM" -lt 8 ] || [ "$V_NUM" -lt 6 ]; then
    USABLE=false
fi

echo "Usable for autonomous agent: $USABLE"
echo ""

# Save results for later use
cat > "$PROJECT_ROOT/.harness/assessment-tmp.txt" << EOF
PROJECT_TYPE=$PROJECT_TYPE
CONTROLLABILITY=$E_SCORE
OBSERVABILITY=$O_SCORE
VERIFICATION=$V_SCORE
USABLE=$USABLE
EOF

echo "Results saved to .harness/assessment-tmp.txt"
