#!/bin/bash
# observability/health.sh - Health check for progressive-scaffolding skill

SKILL_ROOT="${PROJECT_ROOT:-.}"

# Check if required directories exist
check-directories() {
    local missing=0

    if [ ! -d "$SKILL_ROOT/scripts" ]; then
        echo "MISSING: scripts/ directory"
        missing=1
    fi

    if [ ! -d "$SKILL_ROOT/templates" ]; then
        echo "MISSING: templates/ directory"
        missing=1
    fi

    if [ $missing -eq 0 ]; then
        echo "OK: Required directories exist"
        return 0
    else
        echo "FAIL: Required directories missing"
        return 1
    fi
}

# Check if required scripts exist
check-scripts() {
    local required=(
        "detect-project-type.sh"
        "detect-controllability.sh"
        "detect-observability.sh"
        "detect-verification.sh"
        "generate-scaffolding.sh"
    )

    local all_exist=0
    for script in "${required[@]}"; do
        if [ ! -f "$SKILL_ROOT/scripts/$script" ]; then
            echo "MISSING: scripts/$script"
            all_exist=1
        fi
    done

    if [ $all_exist -eq 0 ]; then
        echo "OK: All required scripts exist"
        return 0
    else
        echo "FAIL: Some scripts missing"
        return 1
    fi
}

# Check if templates exist
check-templates() {
    if [ ! -d "$SKILL_ROOT/templates/backend/controllability" ]; then
        echo "MISSING: templates/backend/controllability/"
        return 1
    fi
    if [ ! -d "$SKILL_ROOT/templates/backend/observability" ]; then
        echo "MISSING: templates/backend/observability/"
        return 1
    fi
    echo "OK: Core templates exist"
    return 0
}

# Check SKILL.md exists
check-skill-md() {
    if [ ! -f "$SKILL_ROOT/SKILL.md" ]; then
        echo "MISSING: SKILL.md"
        return 1
    fi
    echo "OK: SKILL.md exists"
    return 0
}

# Full health check
health-check() {
    local overall=0

    echo "=== Health Check ==="
    echo ""

    check-directories || overall=1
    echo ""

    check-scripts || overall=1
    echo ""

    check-templates || overall=1
    echo ""

    check-skill-md || overall=1
    echo ""

    echo "=== Summary ==="
    if [ $overall -eq 0 ]; then
        echo "Status: HEALTHY"
        echo "{\"status\":\"healthy\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
        return 0
    else
        echo "Status: UNHEALTHY"
        echo "{\"status\":\"unhealthy\",\"timestamp\":\"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\"}"
        return 1
    fi
}

# Main
case "${1:-check}" in
    check|health)
        health-check
        ;;
    directories)
        check-directories
        ;;
    scripts)
        check-scripts
        ;;
    templates)
        check-templates
        ;;
    skill-md)
        check-skill-md
        ;;
    *)
        echo "Usage: $0 {check|directories|scripts|templates|skill-md}"
        exit 1
        ;;
esac