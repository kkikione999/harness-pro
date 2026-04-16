#!/bin/bash
# trace.sh - Correlation ID injection and trace management for harness-blogs

set -e

HARNESS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$HARNESS_DIR/../../../../../../.." && pwd)"
TRACE_DIR="$PROJECT_ROOT/.harness/traces"

# Ensure trace directory exists
mkdir -p "$TRACE_DIR"

CORRELATION_ID=""
OPERATION=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --id)
            CORRELATION_ID="$2"
            shift 2
            ;;
        --op)
            OPERATION="$2"
            shift 2
            ;;
        new)
            OPERATION="new"
            shift
            ;;
        list)
            OPERATION="list"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Generate new correlation ID if needed
if [ -z "$CORRELATION_ID" ]; then
    CORRELATION_ID="trace-$$-$(date +%Y%m%d-%H%M%S)"
fi

case "$OPERATION" in
    new)
        echo "=== New Trace Created ==="
        echo "Correlation ID: $CORRELATION_ID"
        echo "Timestamp: $(date -Iseconds)"
        echo ""

        # Write trace file
        TRACE_FILE="$TRACE_DIR/$CORRELATION_ID.json"
        printf '%s\n' '{"correlation_id": "'$CORRELATION_ID'", "created": "'$(date -Iseconds)'", "events": []}' > "$TRACE_FILE"

        echo "Trace file: $TRACE_FILE"
        echo ""
        echo "To annotate this trace:"
        echo "  ./trace.sh --id $CORRELATION_ID --op annotate 'Starting build'"
        echo ""
        echo "To export this trace:"
        echo "  ./trace.sh --id $CORRELATION_ID --op export"
        ;;

    annotate)
        if [ -z "$CORRELATION_ID" ]; then
            echo "Error: --id required for annotate"
            exit 1
        fi
        ANNOTATION="${*:-$1}"
        echo "=== Trace Annotation ==="
        echo "Correlation ID: $CORRELATION_ID"
        echo "Annotation: $ANNOTATION"
        echo "Timestamp: $(date -Iseconds)"
        echo ""

        TRACE_FILE="$TRACE_DIR/$CORRELATION_ID.json"
        if [ -f "$TRACE_FILE" ]; then
            # Append event to trace
            TEMP_FILE=$(mktemp)
            printf '%s\n' '{"timestamp": "'$(date -Iseconds)'", "event": "'$ANNOTATION'"}' >> "$TRACE_FILE"
            echo "Event appended to: $TRACE_FILE"
        else
            echo "Warning: Trace file not found, creating new trace"
            printf '%s\n' '{"correlation_id": "'$CORRELATION_ID'", "created": "'$(date -Iseconds)'", "events": [{"timestamp": "'$(date -Iseconds)'", "event": "'$ANNOTATION'"}]}' > "$TRACE_DIR/$CORRELATION_ID.json"
        fi
        ;;

    list)
        echo "=== Active Traces ==="
        echo "Trace directory: $TRACE_DIR"
        echo ""

        if [ -z "$(ls -A "$TRACE_DIR" 2>/dev/null)" ]; then
            echo "  (No traces found)"
            echo ""
            echo "To create a new trace:"
            echo "  ./trace.sh new"
        else
            echo "Traces:"
            for file in "$TRACE_DIR"/*.json; do
                if [ -f "$file" ]; then
                    NAME="${file%.json}"
                    NAME="${NAME##*/}"
                    # macOS stat format
                    AGE=$(stat -f %Sm -t %Y-%m-%d\ %H:%M "$file" 2>/dev/null)
                    echo "  - $NAME (modified: $AGE)"
                fi
            done | head -10
        fi
        ;;

    export)
        if [ -z "$CORRELATION_ID" ]; then
            echo "Error: --id required for export"
            exit 1
        fi

        TRACE_FILE="$TRACE_DIR/$CORRELATION_ID.json"
        if [ -f "$TRACE_FILE" ]; then
            cat "$TRACE_FILE"
        else
            echo "Error: Trace not found: $CORRELATION_ID"
            exit 1
        fi
        ;;

    *)
        echo "=== Trace Management ==="
        echo "Usage: trace.sh [command]"
        echo ""
        echo "Commands:"
        echo "  trace.sh new                  - Create new trace"
        echo "  trace.sh --id ID annotate MSG - Add annotation to trace"
        echo "  trace.sh list                 - List active traces"
        echo "  trace.sh --id ID export       - Export trace as JSON"
        echo ""
        echo "Environment Variables:"
        echo "  CORRELATION_ID                - Current trace ID (auto-set)"
        echo ""
        echo "Current Correlation ID: ${CORRELATION_ID:-not set}"
        ;;
esac

exit 0
