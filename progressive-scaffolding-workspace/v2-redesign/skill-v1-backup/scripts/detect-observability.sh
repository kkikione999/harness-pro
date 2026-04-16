#!/bin/bash
# detect-observability.sh — Probe O1-O4 observability dimensions
# Output: O1:O2:O3:O4 levels
# Updated: Detect project-specific telemetry infrastructure, not just generic patterns

PROJECT_ROOT="${1:-.}"

cd "$PROJECT_ROOT" || exit 1

echo "=== Observability Assessment ==="
echo ""

# --- Helper: detect telemetry infrastructure ---
TELEMETRY_FOUND=""
TELEMETRY_DIRS=""
TELEMETRY_DETAILS=""

# Check for common telemetry/analytics/tracing directories
for dir in \
    "src/utils/telemetry" "src/services/analytics" "src/services/telemetry" \
    "src/tracing" "src/telemetry" "src/analytics" "src/monitoring" \
    "src/utils/analytics" "src/utils/tracing" "src/utils/monitoring" \
    "lib/telemetry" "lib/analytics" "lib/tracing" "lib/monitoring" \
    "internal/telemetry" "internal/observability" "pkg/telemetry" \
    "app/telemetry" "app/analytics" "app/monitoring"; do
    if [ -d "$dir" ]; then
        TELEMETRY_DIRS="$TELEMETRY_DIRS $dir"
        TELEMETRY_FOUND="yes"
    fi
done

# Check for observability-related source files
TELEMETRY_FILES=$(find . -type f \( -name "*telemetry*" -o -name "*tracing*" -o -name "*analytics*" -o -name "*instrumentation*" -o -name "*metrics*" -o -name "*profiler*" \) \
    ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/vendor/*" ! -path "*/.harness/*" \
    2>/dev/null | head -20)

if [ -n "$TELEMETRY_FILES" ]; then
    TELEMETRY_FOUND="yes"
    TELEMETRY_DETAILS="$TELEMETRY_DETAILS\nTelemetry source files found:"
    echo "$TELEMETRY_FILES" | while read -r f; do
        TELEMETRY_DETAILS="$TELEMETRY_DETAILS\n  - $f"
    done
fi

# Check for observability library imports
OBS_LIBS=""
grep -rl "opentelemetry\|@opencensus\|prom-client\|winston\|pino\|bunyan\|morgan\|helmet\|datadog\|newrelic\|sentry\|jaeger\|zipkin\|grafana\|statsig\|amplitude\|mixpanel" \
    --include="*.ts" --include="*.js" --include="*.go" --include="*.py" \
    . 2>/dev/null | head -10 | while read -r f; do
    OBS_LIBS="$OBS_LIBS $f"
done

# Check for BigQuery/Prometheus/OTEL exporters
EXPORTER_FILES=""
grep -rl "bigquery\|prometheus\|otlp\|otlpexporter\|PerfettoTrace\|chrome.*trace" \
    --include="*.ts" --include="*.js" --include="*.go" --include="*.py" \
    . 2>/dev/null | head -10 | while read -r f; do
    EXPORTER_FILES="$EXPORTER_FILES $f"
done

# Print telemetry detection results
if [ -n "$TELEMETRY_FOUND" ]; then
    echo "Telemetry Infrastructure Detected:"
    if [ -n "$TELEMETRY_DIRS" ]; then
        for dir in $TELEMETRY_DIRS; do
            FILE_COUNT=$(find "$dir" -type f 2>/dev/null | wc -l | tr -d ' ')
            echo "  - $dir/ ($FILE_COUNT files)"
        done
    fi
    if [ -n "$TELEMETRY_FILES" ]; then
        echo "$TELEMETRY_FILES" | head -10 | while read -r f; do
            [ -n "$f" ] && echo "  - $f"
        done
    fi
    echo ""
fi

# O1: Feedback — Can system output information?
O1_LEVEL=1
O1_EVIDENCE="Basic stdout only"

if grep -r "console.log\|console.error\|console.warn\|fmt.Print\|print\|echo\|logging" \
    --include="*.go" --include="*.py" --include="*.js" --include="*.ts" . 2>/dev/null | head -5 | grep -q .; then
    O1_LEVEL=2
    O1_EVIDENCE="Has structured output (console/logging)"
fi

if [ -f "package.json" ] && grep -q '"scripts"' package.json 2>/dev/null; then
    O1_LEVEL=2
    O1_EVIDENCE="$O1_EVIDENCE; npm scripts"
fi

if [ -f "Makefile" ] && grep -q "echo\|printf" Makefile 2>/dev/null; then
    O1_LEVEL=2
fi

# Level 3: typed/structured outputs (JSON logs, OTLP, etc.)
if grep -rl "JSON.stringify\|json.Marshal\|json.dumps\|JSON\.parse" \
    --include="*.ts" --include="*.js" --include="*.go" --include="*.py" . 2>/dev/null | head -3 | grep -q .; then
    O1_LEVEL=3
    O1_EVIDENCE="$O1_EVIDENCE; JSON structured output"
fi

if [ -n "$TELEMETRY_FOUND" ]; then
    O1_LEVEL=3
    O1_EVIDENCE="$O1_EVIDENCE; telemetry infrastructure detected"
fi

# O2: Persist — Is information retained?
O2_LEVEL=1
O2_EVIDENCE="No log persistence"

if [ -d "logs" ] || [ -d "log" ]; then
    O2_LEVEL=2
    O2_EVIDENCE="Has log directory"
fi

# Check for structured logging frameworks
if grep -r "winston\|pino\|bunyan\|logrus\|zap\|structlog\|logging.basicConfig" \
    --include="*.go" --include="*.js" --include="*.ts" --include="*.py" . 2>/dev/null | head -3 | grep -q .; then
    O2_LEVEL=3
    O2_EVIDENCE="Has structured logging framework"
fi

# Check telemetry persistence (session tracing, BigQuery exporters, etc.)
if [ -n "$TELEMETRY_FOUND" ]; then
    if grep -rl "bigquery\|prometheus\|otlp\|PerfettoTrace\|session.*trac\|transcript" \
        --include="*.ts" --include="*.js" --include="*.go" --include="*.py" \
        . 2>/dev/null | head -3 | grep -q .; then
        O2_LEVEL=3
        O2_EVIDENCE="$O2_EVIDENCE; telemetry persistence (exporters/tracing)"
    fi
fi

# O3: Queryable — Can history be searched?
O3_LEVEL=1
O3_EVIDENCE="Logs not searchable"

if [ -d ".harness/observability" ]; then
    O3_LEVEL=2
    O3_EVIDENCE="Has .harness/observability query scripts"
fi

if command -v jq > /dev/null 2>&1; then
    # Check if there are JSON log files to query
    if find . -name "*.jsonl" -o -name "*.ndjson" -o -name "log*.json" 2>/dev/null | head -3 | grep -q .; then
        O3_LEVEL=2
        O3_EVIDENCE="$O3_EVIDENCE; jq + JSON logs available"
    fi
fi

# Level 3: full query language (log aggregation, BigQuery SQL, etc.)
if grep -rl "logql\|elasticsearch\|kibana\|grafana.*query\|bigquery.*query\|SELECT.*FROM" \
    --include="*.ts" --include="*.js" --include="*.go" --include="*.py" . 2>/dev/null | head -3 | grep -q .; then
    O3_LEVEL=3
    O3_EVIDENCE="Has log query/aggregation system"
fi

# O4: Attribute — Can causes be traced to results?
O4_LEVEL=1
O4_EVIDENCE="No tracing"

if grep -r "request.id\|correlation.id\|trace.id\|x-request-id\|correlationId\|traceId\|spanId\|session.*id\|parent_session" \
    --include="*.go" --include="*.js" --include="*.ts" --include="*.py" . 2>/dev/null | head -3 | grep -q .; then
    O4_LEVEL=2
    O4_EVIDENCE="Has correlation/trace IDs"
fi

# Level 3: full distributed tracing
if grep -rl "opentelemetry\|@opencensus\|jaeger\|zipkin\|datadog.*trace\|span.*context\|trace.*context" \
    --include="*.ts" --include="*.js" --include="*.go" --include="*.py" . 2>/dev/null | head -5 | grep -q .; then
    O4_LEVEL=3
    O4_EVIDENCE="Has distributed tracing"
fi

if [ -f "docker-compose.yml" ] && grep -q "request.id\|trace\|jaeger\|zipkin" docker-compose.yml 2>/dev/null; then
    O4_LEVEL=3
fi

echo "O1_FEEDBACK: Level $O1_LEVEL"
echo "O2_PERSIST: Level $O2_LEVEL"
echo "O3_QUERYABLE: Level $O3_LEVEL"
echo "O4_ATTRIBUTE: Level $O4_LEVEL"
echo ""

# Evidence
echo "Evidence:"
echo "- O1: $O1_EVIDENCE"
echo "- O2: $O2_EVIDENCE"
echo "- O3: $O3_EVIDENCE"
echo "- O4: $O4_EVIDENCE"
echo ""

# Calculate total
TOTAL=$((O1_LEVEL + O2_LEVEL + O3_LEVEL + O4_LEVEL))
MAX=12
echo "Observability Score: $TOTAL/$MAX"

# Exit code
[ $TOTAL -ge 8 ] && exit 0 || exit 1
