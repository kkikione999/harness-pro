#!/bin/bash
# metrics.sh - Metrics endpoint query and status for Open-ClaudeCode
# Queries OpenTelemetry metrics configuration, Prometheus exporters,
# BigQuery metrics exporter, and Datadog analytics pipeline.
#
# Usage:
#   ./metrics.sh status              - Show all metrics pipeline status
#   ./metrics.sh otel                - Show OTEL metrics config
#   ./metrics.sh bigquery            - Show BigQuery metrics exporter status
#   ./metrics.sh datadog             - Show Datadog event metrics
#   ./metrics.sh prometheus          - Query Prometheus endpoint (if running)
#   ./metrics.sh counters            - Show available metric counters
#   ./metrics.sh export              - Trigger a metrics flush

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CLAUDE_CONFIG_HOME="${CLAUDE_CONFIG_HOME:-$HOME/.claude}"

# Color output helpers
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_debug() { echo -e "${CYAN}[DEBUG]${NC} $*"; }

COMMAND="${1:-status}"

case "$COMMAND" in
    status)
        echo "=== Open-ClaudeCode Metrics Status ==="
        echo ""

        # Overall telemetry status
        if [ -n "${CLAUDE_CODE_ENABLE_TELEMETRY:-}" ]; then
            log_info "Telemetry: ENABLED"
        else
            log_warn "Telemetry: DISABLED"
            echo "  Set CLAUDE_CODE_ENABLE_TELEMETRY=1 to enable"
        fi
        echo ""

        # OTEL Metrics
        echo "--- OpenTelemetry Metrics ---"
        echo "  Exporter: ${OTEL_METRICS_EXPORTER:-<not configured>}"
        echo "  Export interval: ${OTEL_METRIC_EXPORT_INTERVAL:-60000ms (default)}"
        echo "  Protocol: ${OTEL_EXPORTER_OTLP_PROTOCOL:-<not configured>}"
        echo "  Endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:-<not configured>}"
        echo "  Temporality: ${OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE:-delta (default)}"
        echo "  Service: claude-code"
        echo ""

        # BigQuery
        echo "--- BigQuery Metrics Exporter ---"
        echo "  Enabled for: API customers, C4E users, Teams users"
        echo "  Endpoint: https://api.anthropic.com/api/claude_code/metrics"
        echo "  Export interval: 5 minutes"
        echo "  Temporality: delta"
        echo "  Source: src/utils/telemetry/bigqueryExporter.ts"
        echo ""

        # Datadog
        echo "--- Datadog Event Metrics ---"
        echo "  Endpoint: https://http-intake.logs.us5.datadoghq.com/api/v2/logs"
        echo "  Service: claude-code"
        echo "  Batch size: max 100 logs"
        echo "  Flush interval: ${CLAUDE_CODE_DATADOG_FLUSH_INTERVAL_MS:-15000ms (default)}"
        echo "  Gate: tengu_log_datadog_events"
        echo "  Source: src/services/analytics/datadog.ts"
        echo ""

        # 1P Event Logging
        echo "--- 1P Event Logging ---"
        echo "  Endpoint: /api/event_logging/batch"
        echo "  Default batch size: 200"
        echo "  Default queue size: 8192"
        echo "  Default export interval: 10000ms"
        echo "  Config: tengu_1p_event_batch_config (GrowthBook)"
        echo "  Source: src/services/analytics/firstPartyEventLogger.ts"
        ;;

    otel)
        echo "=== OpenTelemetry Metrics Configuration ==="
        echo ""

        if [ -z "${CLAUDE_CODE_ENABLE_TELEMETRY:-}" ]; then
            log_warn "OTEL telemetry is disabled"
            echo ""
            echo "To enable:"
            echo "  export CLAUDE_CODE_ENABLE_TELEMETRY=1"
            echo "  export OTEL_METRICS_EXPORTER=console   # or otlp, prometheus"
            echo ""
            echo "For OTLP:"
            echo "  export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318"
            echo "  export OTEL_EXPORTER_OTLP_PROTOCOL=http/json  # or grpc, http/protobuf"
            exit 0
        fi

        log_info "OTEL metrics configuration:"
        echo "  Metrics exporter: ${OTEL_METRICS_EXPORTER:-not set}"
        echo "  Export interval: ${OTEL_METRIC_EXPORT_INTERVAL:-60000}ms"
        echo "  Protocol: ${OTEL_EXPORTER_OTLP_PROTOCOL:-not set}"
        echo "  Endpoint: ${OTEL_EXPORTER_OTLP_ENDPOINT:-not set}"
        echo "  Headers: $([ -n "${OTEL_EXPORTER_OTLP_HEADERS:-}" ] && echo 'configured' || echo 'not set')"
        echo "  Temporality: ${OTEL_EXPORTER_OTLP_METRICS_TEMPORALITY_PREFERENCE:-delta}"
        echo ""
        echo "  Source: src/utils/telemetry/instrumentation.ts"
        echo "  Meter: com.anthropic.claude_code"
        ;;

    bigquery)
        echo "=== BigQuery Metrics Exporter ==="
        echo ""

        log_info "BigQuery metrics are shipped to Anthropic's internal metrics pipeline."
        echo ""
        echo "Eligibility:"
        echo "  - API customers (first-party API key users)"
        echo "  - Claude for Enterprise (C4E) subscribers"
        echo "  - Claude for Teams subscribers"
        echo ""
        echo "Export configuration:"
        echo "  Endpoint: ${ANT_CLAUDE_CODE_METRICS_ENDPOINT:-https://api.anthropic.com}/api/claude_code/metrics"
        echo "  Export interval: 5 minutes (reduces load)"
        echo "  Aggregation: delta temporality"
        echo "  Timeout: 5000ms"
        echo ""
        echo "Resource attributes exported:"
        echo "  - service.name, service.version"
        echo "  - os.type, os.version, host.arch"
        echo "  - user.customer_type, user.subscription_type"
        echo ""
        echo "  Source: src/utils/telemetry/bigqueryExporter.ts"
        ;;

    datadog)
        echo "=== Datadog Event Metrics ==="
        echo ""

        if [ "${NODE_ENV:-}" != "production" ]; then
            log_warn "Datadog events only fire in NODE_ENV=production"
            echo "  Current: NODE_ENV=${NODE_ENV:-<not set>}"
        else
            log_info "Datadog is active (NODE_ENV=production)"
        fi

        echo ""
        echo "Allowed event types (DATADOG_ALLOWED_EVENTS):"
        echo "  tengu_api_success, tengu_api_error"
        echo "  tengu_tool_use_success, tengu_tool_use_error"
        echo "  tengu_init, tengu_exit, tengu_started"
        echo "  tengu_cancel, tengu_query_error"
        echo "  tengu_uncaught_exception, tengu_unhandled_rejection"
        echo "  chrome_bridge_* (7 events)"
        echo "  tengu_oauth_* (8 events)"
        echo "  tengu_model_fallback_triggered"
        echo "  tengu_compact_failed, tengu_flicker"
        echo "  tengu_brief_mode_* (3 events)"
        echo "  tengu_voice_* (2 events)"
        echo "  tengu_team_mem_* (4 events)"
        echo ""
        echo "Tag fields (cardinality controls):"
        echo "  arch, clientType, errorType, http_status, http_status_range"
        echo "  kairosActive, model, platform, provider, skillMode"
        echo "  subscriptionType, toolName, userBucket, userType, version"
        echo ""
        echo "User bucketing: $NUM_USER_BUCKETS buckets (30) for unique user estimation"
        echo "  Source: src/services/analytics/datadog.ts"
        ;;

    prometheus)
        echo "=== Prometheus Exporter ==="
        echo ""

        if [ "${OTEL_METRICS_EXPORTER:-}" != "prometheus" ]; then
            log_warn "Prometheus exporter not configured"
            echo ""
            echo "To enable:"
            echo "  export CLAUDE_CODE_ENABLE_TELEMETRY=1"
            echo "  export OTEL_METRICS_EXPORTER=prometheus"
            echo ""
            echo "Then query the metrics endpoint:"
            echo "  curl http://localhost:9464/metrics"
        else
            log_info "Prometheus exporter is configured"
            PROMETHEUS_PORT="${OTEL_EXPORTER_PROMETHEUS_PORT:-9464}"
            PROMETHEUS_HOST="${OTEL_EXPORTER_PROMETHEUS_HOST:-localhost}"
            ENDPOINT="http://${PROMETHEUS_HOST}:${PROMETHEUS_PORT}/metrics"

            if command -v curl > /dev/null 2>&1; then
                echo "Querying $ENDPOINT ..."
                HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "$ENDPOINT" 2>/dev/null || echo "000")
                if [ "$HTTP_CODE" = "200" ]; then
                    log_info "Prometheus endpoint is reachable"
                    curl -s "$ENDPOINT" 2>/dev/null | head -50
                else
                    log_error "Prometheus endpoint returned HTTP $HTTP_CODE"
                    log_info "Is the claude-code process running with Prometheus enabled?"
                fi
            else
                log_warn "curl not available to query Prometheus endpoint"
            fi
        fi
        ;;

    counters)
        echo "=== Available Metric Counters ==="
        echo ""
        log_info "OpenTelemetry Meter: com.anthropic.claude_code"
        echo ""
        echo "The meter is created in: src/utils/telemetry/instrumentation.ts"
        echo ""
        echo "Metric signals exported:"
        echo "  - Token usage (input, output, cache_read, cache_creation)"
        echo "  - Request counts and latencies"
        echo "  - Tool execution metrics"
        echo "  - Session duration"
        echo "  - Interaction counts"
        echo ""
        echo "Custom exporters:"
        echo "  - BigQuery (delta aggregation, 5min interval)"
        echo "  - OTLP (grpc, http/json, http/protobuf)"
        echo "  - Prometheus (pull-based)"
        echo "  - Console (debugging)"
        echo ""
        echo "Event-level metrics (non-OTEL):"
        echo "  - Datadog: tengu_* event logs with metric attributes"
        echo "  - 1P Events: batched to /api/event_logging/batch"
        ;;

    export)
        echo "=== Triggering Metrics Flush ==="
        echo ""

        # This signals the running process to flush via env var
        FLUSH_FILE="$CLAUDE_CONFIG_HOME/.metrics-flush-request"
        log_info "Writing flush signal to $FLUSH_FILE"
        echo "$(date -Iseconds)" > "$FLUSH_FILE"

        log_info "Flush signal written."
        echo ""
        echo "Note: Open-ClaudeCode flushes telemetry on:"
        echo "  - Process beforeExit event"
        echo "  - Process exit event"
        echo "  - Cleanup registry (graceful shutdown)"
        echo "  - Logout/org switch (flushTelemetry())"
        echo ""
        echo "Shutdown timeout: ${CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS:-2000}ms"
        echo "Flush timeout: ${CLAUDE_CODE_OTEL_FLUSH_TIMEOUT_MS:-5000}ms"
        ;;

    *)
        echo "Usage: ./metrics.sh [status|otel|bigquery|datadog|prometheus|counters|export]"
        echo ""
        echo "Commands:"
        echo "  status       Show all metrics pipeline status (default)"
        echo "  otel         Show OTEL metrics configuration"
        echo "  bigquery     Show BigQuery metrics exporter details"
        echo "  datadog      Show Datadog event metrics details"
        echo "  prometheus   Query Prometheus endpoint (if running)"
        echo "  counters     Show available metric counters"
        echo "  export       Trigger a metrics flush signal"
        ;;
esac
