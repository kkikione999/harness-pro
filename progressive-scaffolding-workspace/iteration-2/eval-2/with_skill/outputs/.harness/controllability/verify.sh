#!/bin/bash
# controllability/verify.sh - Verification script for progressive-scaffolding skill

set -e

SKILL_ROOT="${PROJECT_ROOT:-.}"

# Verify all probes can run
verify-probes() {
    echo "=== Verifying Assessment Probes ==="

    echo -n "detect-project-type.sh: "
    if bash "$SKILL_ROOT/scripts/detect-project-type.sh" "$SKILL_ROOT" > /dev/null 2>&1; then
        echo "OK"
    else
        echo "FAIL"
        return 1
    fi

    echo -n "detect-controllability.sh: "
    if bash "$SKILL_ROOT/scripts/detect-controllability.sh" "$SKILL_ROOT" > /dev/null 2>&1; then
        echo "OK"
    else
        echo "FAIL"
        return 1
    fi

    echo -n "detect-observability.sh: "
    if bash "$SKILL_ROOT/scripts/detect-observability.sh" "$SKILL_ROOT" > /dev/null 2>&1; then
        echo "OK"
    else
        echo "FAIL"
        return 1
    fi

    echo -n "detect-verification.sh: "
    if bash "$SKILL_ROOT/scripts/detect-verification.sh" "$SKILL_ROOT" > /dev/null 2>&1; then
        echo "OK"
    else
        echo "FAIL"
        return 1
    fi

    echo "All probes verified successfully"
    return 0
}

# Verify scaffolding exists
verify-scaffolding() {
    echo "=== Verifying Scaffolding ==="

    local required=(
        ".harness/controllability"
        ".harness/observability"
    )

    for dir in "${required[@]}"; do
        if [ ! -d "$SKILL_ROOT/$dir" ]; then
            echo "MISSING: $dir"
            return 1
        fi
    done

    echo "Scaffolding structure verified"
    return 0
}

# Main
echo "=== Verification ==="
echo ""

if verify-probes && verify-scaffolding; then
    echo ""
    echo "Status: VERIFIED"
    exit 0
else
    echo ""
    echo "Status: VERIFICATION FAILED"
    exit 1
fi