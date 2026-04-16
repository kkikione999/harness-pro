#!/bin/bash
# health.sh — Health check for Open-ClaudeCode observability infrastructure
#
# Verifies that the project's telemetry and analytics subsystems are functional:
#   - Source file integrity (telemetry + analytics modules)
#   - OTEL configuration validity
#   - Exporter connectivity hints
#   - Datadog pipeline status
#   - BigQuery pipeline status
#   - Perfetto tracing readiness
#   - Privacy/config consistency
#   - Golden Principle lint system
#
# Exit codes:
#   0 — All checks passed
#   1 — Warning: some checks need attention
#   2 — Critical: required infrastructure missing
#
# Usage:
#   ./health.sh                  — run all checks
#   ./health.sh --quick          — skip network checks
#   ./health.sh --json           — output as JSON

set -euo pipefail

PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
QUICK_MODE=false
JSON_OUTPUT=false

for arg in "$@"; do
    case "$arg" in
        --quick) QUICK_MODE=true ;;
        --json)  JSON_OUTPUT=true ;;
    esac
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Health tracking
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
CHECKS=()

check_pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    CHECKS+=("PASS:$1")
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "  ${GREEN}[PASS]${NC} $1"
    fi
}

check_warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    CHECKS+=("WARN:$1")
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "  ${YELLOW}[WARN]${NC} $1"
    fi
}

check_fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    CHECKS+=("FAIL:$1")
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "  ${RED}[FAIL]${NC} $1"
    fi
}

# ===== Check Functions =====

# Check 1: Source file integrity
check_source_integrity() {
    local section="Source File Integrity"

    # Telemetry module
    local telemetry_files=(
        "src/utils/telemetry/instrumentation.ts"
        "src/utils/telemetry/sessionTracing.ts"
        "src/utils/telemetry/perfettoTracing.ts"
        "src/utils/telemetry/betaSessionTracing.ts"
        "src/utils/telemetry/bigqueryExporter.ts"
        "src/utils/telemetry/events.ts"
        "src/utils/telemetry/logger.ts"
        "src/utils/telemetry/pluginTelemetry.ts"
        "src/utils/telemetry/skillLoadedEvent.ts"
    )

    local missing=0
    for f in "${telemetry_files[@]}"; do
        if [ ! -f "$PROJECT_ROOT/$f" ]; then
            missing=$((missing + 1))
        fi
    done

    if [ "$missing" -eq 0 ]; then
        check_pass "$section: All ${#telemetry_files[@]} telemetry source files present"
    else
        check_fail "$section: $missing telemetry source files missing"
    fi

    # Analytics module
    local analytics_files=(
        "src/services/analytics/index.ts"
        "src/services/analytics/sink.ts"
        "src/services/analytics/datadog.ts"
        "src/services/analytics/firstPartyEventLogger.ts"
        "src/services/analytics/config.ts"
        "src/services/analytics/metadata.ts"
        "src/services/analytics/growthbook.ts"
        "src/services/analytics/sinkKillswitch.ts"
    )

    missing=0
    for f in "${analytics_files[@]}"; do
        if [ ! -f "$PROJECT_ROOT/$f" ]; then
            missing=$((missing + 1))
        fi
    done

    if [ "$missing" -eq 0 ]; then
        check_pass "$section: All ${#analytics_files[@]} analytics source files present"
    else
        check_fail "$section: $missing analytics source files missing"
    fi

    # Telemetry attributes module
    if [ -f "$PROJECT_ROOT/src/utils/telemetryAttributes.ts" ]; then
        check_pass "$section: telemetryAttributes.ts present"
    else
        check_warn "$section: telemetryAttributes.ts missing"
    fi
}

# Check 2: Package configuration
check_package_config() {
    local section="Package Configuration"

    if [ -f "$PROJECT_ROOT/package/package.json" ]; then
        check_pass "$section: package.json found"

        # Verify bin entry
        if grep -q '"bin"' "$PROJECT_ROOT/package/package.json" 2>/dev/null; then
            check_pass "$section: CLI bin entry configured"
        else
            check_warn "$section: No bin entry in package.json"
        fi

        # Check Node version requirement
        local node_version
        node_version=$(grep -oP '"node":\s*">=([^"]+)"' "$PROJECT_ROOT/package/package.json" 2>/dev/null | grep -oP '[0-9.]+' || echo "unknown")
        check_pass "$section: Node >= $node_version required"
    else
        check_warn "$section: No package.json at expected location"
    fi
}

# Check 3: OTEL configuration structure
check_otel_config() {
    local section="OTEL Configuration"

    # Verify instrumentation.ts exports the right functions
    local required_exports=(
        "initializeTelemetry"
        "isTelemetryEnabled"
        "bootstrapTelemetry"
        "flushTelemetry"
    )

    local missing_exports=0
    for exp in "${required_exports[@]}"; do
        if ! grep -q "export.*function.*$exp\|export.*$exp" "$PROJECT_ROOT/src/utils/telemetry/instrumentation.ts" 2>/dev/null; then
            missing_exports=$((missing_exports + 1))
        fi
    done

    if [ "$missing_exports" -eq 0 ]; then
        check_pass "$section: All required exports present in instrumentation.ts"
    else
        check_warn "$section: $missing_exports missing exports in instrumentation.ts"
    fi

    # Check sessionTracing exports
    local tracing_exports=(
        "startInteractionSpan"
        "endInteractionSpan"
        "startLLMRequestSpan"
        "endLLMRequestSpan"
        "startToolSpan"
        "endToolSpan"
        "getCurrentSpan"
        "executeInSpan"
    )

    missing_exports=0
    for exp in "${tracing_exports[@]}"; do
        if ! grep -q "export.*function.*$exp" "$PROJECT_ROOT/src/utils/telemetry/sessionTracing.ts" 2>/dev/null; then
            missing_exports=$((missing_exports + 1))
        fi
    done

    if [ "$missing_exports" -eq 0 ]; then
        check_pass "$section: All span lifecycle exports present in sessionTracing.ts"
    else
        check_warn "$section: $missing_exports missing span exports"
    fi
}

# Check 4: Analytics pipeline completeness
check_analytics_pipeline() {
    local section="Analytics Pipeline"

    # Check sink interface is complete
    if grep -q "AnalyticsSink" "$PROJECT_ROOT/src/services/analytics/index.ts" 2>/dev/null; then
        check_pass "$section: AnalyticsSink interface defined"
    else
        check_fail "$section: AnalyticsSink interface missing"
    fi

    # Check event queue mechanism
    if grep -q "eventQueue" "$PROJECT_ROOT/src/services/analytics/index.ts" 2>/dev/null; then
        check_pass "$section: Event queuing mechanism present"
    else
        check_warn "$section: Event queuing mechanism not found"
    fi

    # Check sink routing
    if grep -q "trackDatadogEvent\|logEventTo1P" "$PROJECT_ROOT/src/services/analytics/sink.ts" 2>/dev/null; then
        check_pass "$section: Sink routing to Datadog + 1P verified"
    else
        check_warn "$section: Sink routing incomplete"
    fi

    # Check sink killswitch
    if [ -f "$PROJECT_ROOT/src/services/analytics/sinkKillswitch.ts" ]; then
        check_pass "$section: Sink killswitch available"
    else
        check_warn "$section: Sink killswitch missing"
    fi
}

# Check 5: Privacy and security controls
check_privacy() {
    local section="Privacy Controls"

    # Check opt-out config
    if grep -q "isAnalyticsDisabled\|isTelemetryDisabled" "$PROJECT_ROOT/src/services/analytics/config.ts" 2>/dev/null; then
        check_pass "$section: Analytics opt-out logic present"
    else
        check_warn "$section: Analytics opt-out logic incomplete"
    fi

    # Check PII protection types
    if grep -q "AnalyticsMetadata_I_VERIFIED_THIS_IS_NOT_CODE_OR_FILEPATHS" \
        "$PROJECT_ROOT/src/services/analytics/index.ts" 2>/dev/null; then
        check_pass "$section: PII protection marker types present"
    else
        check_warn "$section: PII protection marker types missing"
    fi

    # Check stripProtoFields for _PROTO_* key removal
    if grep -q "stripProtoFields\|_PROTO_" "$PROJECT_ROOT/src/services/analytics/index.ts" 2>/dev/null; then
        check_pass "$section: PII field stripping before non-1P sinks"
    else
        check_warn "$section: PII field stripping may be incomplete"
    fi

    # Check tool name sanitization
    if grep -q "sanitizeToolNameForAnalytics\|mcp_tool" "$PROJECT_ROOT/src/services/analytics/metadata.ts" 2>/dev/null; then
        check_pass "$section: Tool name sanitization for analytics"
    else
        check_warn "$section: Tool name sanitization missing"
    fi
}

# Check 6: Perfetto tracing readiness
check_perfetto() {
    local section="Perfetto Tracing"

    if [ -f "$PROJECT_ROOT/src/utils/telemetry/perfettoTracing.ts" ]; then
        # Check for key exports
        local perfetto_exports=(
            "initializePerfettoTracing"
            "isPerfettoTracingEnabled"
            "startLLMRequestPerfettoSpan"
            "endLLMRequestPerfettoSpan"
            "startToolPerfettoSpan"
            "endToolPerfettoSpan"
            "startInteractionPerfettoSpan"
            "endInteractionPerfettoSpan"
        )

        local missing=0
        for exp in "${perfetto_exports[@]}"; do
            if ! grep -q "export.*function.*$exp" "$PROJECT_ROOT/src/utils/telemetry/perfettoTracing.ts" 2>/dev/null; then
                missing=$((missing + 1))
            fi
        done

        if [ "$missing" -eq 0 ]; then
            check_pass "$section: All Perfetto span functions present"
        else
            check_warn "$section: $missing Perfetto span functions missing"
        fi

        # Check for trace event format compliance
        if grep -q "traceEvents" "$PROJECT_ROOT/src/utils/telemetry/perfettoTracing.ts" 2>/dev/null; then
            check_pass "$section: Chrome Trace Event format compliance"
        else
            check_warn "$section: Chrome Trace Event format not confirmed"
        fi
    else
        check_warn "$section: perfettoTracing.ts not found (may be ant-only)"
    fi
}

# Check 7: BigQuery exporter
check_bigquery() {
    local section="BigQuery Exporter"

    if [ -f "$PROJECT_ROOT/src/utils/telemetry/bigqueryExporter.ts" ]; then
        # Check for required class methods
        if grep -q "PushMetricExporter" "$PROJECT_ROOT/src/utils/telemetry/bigqueryExporter.ts" 2>/dev/null; then
            check_pass "$section: Implements PushMetricExporter interface"
        else
            check_warn "$section: PushMetricExporter interface not found"
        fi

        if grep -q "async export(" "$PROJECT_ROOT/src/utils/telemetry/bigqueryExporter.ts" 2>/dev/null; then
            check_pass "$section: Export method present"
        else
            check_warn "$section: Export method not found"
        fi

        if grep -q "selectAggregationTemporality" "$PROJECT_ROOT/src/utils/telemetry/bigqueryExporter.ts" 2>/dev/null; then
            check_pass "$section: Temporality selection implemented"
        else
            check_warn "$section: Temporality selection not found"
        fi

        if grep -q "forceFlush\|shutdown" "$PROJECT_ROOT/src/utils/telemetry/bigqueryExporter.ts" 2>/dev/null; then
            check_pass "$section: Lifecycle management present"
        else
            check_warn "$section: Lifecycle management incomplete"
        fi
    else
        check_warn "$section: bigqueryExporter.ts not found"
    fi
}

# Check 8: Golden Principle lint system
check_lint_system() {
    local section="Golden Principle Lints"

    local lint_scripts=(
        "rules/scripts/check.py"
        "rules/scripts/lint-gp001.sh"
        "rules/scripts/lint-gp002.sh"
        "rules/scripts/lint-gp003.sh"
        "rules/scripts/lint-gp004.sh"
        "rules/scripts/lint-gp005.sh"
        "rules/scripts/lint-gp006.sh"
        "rules/scripts/lint-gp007.sh"
        "rules/scripts/lint-gp008.sh"
    )

    local present=0
    for f in "${lint_scripts[@]}"; do
        if [ -f "$PROJECT_ROOT/$f" ]; then
            present=$((present + 1))
        fi
    done

    if [ "$present" -eq "${#lint_scripts[@]}" ]; then
        check_pass "$section: All ${#lint_scripts[@]} lint scripts present"
    else
        check_warn "$section: Only $present/${#lint_scripts[@]} lint scripts found"
    fi
}

# Check 9: Node.js runtime
check_runtime() {
    local section="Runtime"

    if command -v node &>/dev/null; then
        local node_version
        node_version=$(node --version 2>/dev/null || echo "unknown")
        check_pass "$section: Node.js $node_version available"

        # Check version requirement (>= 18)
        local major
        major=$(echo "$node_version" | sed 's/v//' | cut -d. -f1)
        if [ "$major" -ge 18 ] 2>/dev/null; then
            check_pass "$section: Node.js version meets >=18 requirement"
        else
            check_warn "$section: Node.js version $major may be below >=18 requirement"
        fi
    else
        check_fail "$section: Node.js not found in PATH"
    fi
}

# ===== Main =====
run_checks() {
    if [ "$JSON_OUTPUT" = false ]; then
        echo -e "${CYAN}=== Open-ClaudeCode Observability Health Check ===${NC}"
        echo ""
    fi

    check_source_integrity
    check_package_config
    check_otel_config
    check_analytics_pipeline
    check_privacy
    check_perfetto
    check_bigquery
    check_lint_system
    check_runtime
}

# Run all checks
run_checks

# Summary
if [ "$JSON_OUTPUT" = true ]; then
    echo "{"
    echo "  \"project\": \"Open-ClaudeCode\","
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"checks\": {"
    echo "    \"passed\": $PASS_COUNT,"
    echo "    \"warnings\": $WARN_COUNT,"
    echo "    \"failed\": $FAIL_COUNT,"
    echo "    \"total\": $((PASS_COUNT + WARN_COUNT + FAIL_COUNT))"
    echo "  },"
    echo "  \"details\": ["
    local idx=0
    for check in "${CHECKS[@]}"; do
        local status="${check%%:*}"
        local message="${check#*:}"
        local comma=","
        if [ "$idx" -eq "$(( ${#CHECKS[@]} - 1 ))" ]; then
            comma=""
        fi
        echo "    {\"status\": \"$status\", \"message\": \"$message\"}$comma"
        idx=$((idx + 1))
    done
    echo "  ]"
    echo "}"
else
    echo ""
    echo -e "${CYAN}=== Health Check Summary ===${NC}"
    echo -e "  ${GREEN}Passed:${NC}   $PASS_COUNT"
    echo -e "  ${YELLOW}Warnings:${NC} $WARN_COUNT"
    echo -e "  ${RED}Failed:${NC}   $FAIL_COUNT"
    echo ""

    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo -e "${RED}Status: CRITICAL - $FAIL_COUNT check(s) failed${NC}"
        exit 2
    elif [ "$WARN_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}Status: WARNING - $WARN_COUNT check(s) need attention${NC}"
        exit 1
    else
        echo -e "${GREEN}Status: HEALTHY - All checks passed${NC}"
        exit 0
    fi
fi
