#!/bin/bash
# observability/trace.sh - Correlation ID injection for progressive-scaffolding skill

# Generate a new correlation ID
new-correlation-id() {
    if command -v uuidgen >/dev/null 2>&1; then
        uuidgen | tr '[:upper:]' '[:lower:]'
    elif command -v uuid >/dev/null 2>&1; then
        uuid
    else
        # Fallback: timestamp + random
        date -u +"%Y%m%d%H%M%S"-"$(head -c 8 /dev/urandom | xxd -p)"
    fi
}

# Get or create correlation ID
get-correlation-id() {
    echo "${CORRELATION_ID:-$(new-correlation-id)}"
}

# Export correlation ID for child processes
export-correlation-id() {
    export CORRELATION_ID=$(get-correlation-id)
    echo "CORRELATION_ID=$CORRELATION_ID"
    echo "$CORRELATION_ID"
}

# Run a command with correlation ID tracing
run-with-trace() {
    export-correlation-id > /dev/null
    local cmd="$1"
    shift
    echo "[trace] correlation_id=$CORRELATION_ID executing: $cmd $*"
    "$cmd" "$@"
    local exit_code=$?
    echo "[trace] correlation_id=$CORRELATION_ID completed: exit=$exit_code"
    return $exit_code
}

# Inject correlation ID into a file (for HTTP headers, etc.)
inject-into-file() {
    local file="$1"
    local cid=$(get-correlation-id)
    if [ -f "$file" ]; then
        sed -i.bak "s/X-Correlation-ID:.*/X-Correlation-ID: $cid/g" "$file"
        echo "Injected correlation ID into $file"
    else
        echo "x-correlation-id: $cid" >> "$file"
        echo "Created $file with correlation ID"
    fi
}

# Main
case "${1:-get}" in
    new)
        new-correlation-id
        ;;
    get)
        get-correlation-id
        ;;
    export)
        export-correlation-id
        ;;
    run)
        run-with-trace "${2:-echo}" "${@:3}"
        ;;
    inject)
        inject-into-file "${2:-headers.txt}"
        ;;
    *)
        echo "Usage: $0 {new|get|export|run|inject}"
        echo "  new     - Generate new correlation ID"
        echo "  get     - Get current or create new correlation ID"
        echo "  export  - Export CORRELATION_ID to environment"
        echo "  run     - Run command with tracing"
        echo "  inject  - Inject correlation ID into file"
        exit 1
        ;;
esac