#!/bin/bash
# trace.sh — Correlation-ID injection and trace query for Open-ClaudeCode
#
# This script provides tools for working with the project's tracing and
# correlation-ID infrastructure:
#   - Session ID generation and validation
#   - Prompt ID tracking
#   - Span correlation across interaction -> LLM request -> tool -> hook
#   - Parent-child session linking (teammate/subagent hierarchy)
#   - Trace context propagation
#
# Observability dimensions addressed:
#   O4 (Attribute) — trace IDs link causes to results
#   O2 (Persist)   — trace data persisted to Perfetto files
#   O3 (Queryable) — structured queries by correlation IDs
#
# Usage:
#   ./trace.sh summary                — show tracing infrastructure overview
#   ./trace.sh ids                    — list all ID types and their sources
#   ./trace.sh spans                  — show span hierarchy model
#   ./trace.sh correlate <session-id> — query correlated data for a session
#   ./trace.sh hierarchy              — show agent hierarchy model
#   ./trace.sh env                    — show tracing environment controls
#   ./trace.sh validate               — validate trace file format
#   ./trace.sh inject-help            — show how to inject trace context

set -euo pipefail

PROJECT_ROOT="/Users/josh_folder/Open-ClaudeCode"
CLAUDE_HOME="${CLAUDE_CONFIG_HOME:-$HOME/.claude}"
TRACES_DIR="$CLAUDE_HOME/traces"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

has_jq() {
    command -v jq &>/dev/null
}

# --- Command: summary ---
cmd_summary() {
    echo -e "${CYAN}=== Tracing & Correlation-ID Summary ===${NC}"
    echo ""

    echo -e "${BLUE}Tracing Architecture:${NC}"
    echo ""
    echo "  Open-ClaudeCode uses a layered tracing system:"
    echo ""
    echo "  Layer 1: OpenTelemetry (sessionTracing.ts)"
    echo "    - Standard OTEL spans with BatchSpanProcessor"
    echo "    - Exported via OTEL_TRACES_EXPORTER (console, otlp)"
    echo "    - Enabled by: CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1"
    echo ""
    echo "  Layer 2: Beta Tracing (betaSessionTracing.ts)"
    echo "    - Enhanced trace detail with system prompts, model output"
    echo "    - Hash-based deduplication for repeated content"
    echo "    - Enabled by: ENABLE_BETA_TRACING_DETAILED=1 + BETA_TRACING_ENDPOINT"
    echo ""
    echo "  Layer 3: Perfetto (perfettoTracing.ts) [ant-only]"
    echo "    - Chrome Trace Event format for ui.perfetto.dev"
    echo "    - Derived metrics: ITPS, OTPS, cache hit rate"
    echo "    - Enabled by: CLAUDE_CODE_PERFETTO_TRACE=1"
    echo ""
    echo "  Layer 4: OTel Events (events.ts)"
    echo "    - Structured event logging via LoggerProvider"
    echo "    - Carries prompt.id for correlation"
    echo "    - Enabled by: CLAUDE_CODE_ENABLE_TELEMETRY=1"
    echo ""

    echo -e "${BLUE}Correlation ID Inventory:${NC}"
    echo "  session.id        — UUID, per CLI invocation (getSessionId())"
    echo "  prompt.id         — UUID, per user prompt (getPromptId())"
    echo "  user.id           — Hash-based persistent user ID (getOrCreateUserID())"
    echo "  user.account_id   — Tagged ID format: user:<hash>"
    echo "  organization.id   — OAuth org UUID (when authenticated)"
    echo "  span_id           — Per-span, OTEL-generated"
    echo "  trace_id          — Per-trace, OTEL-generated"
    echo "  agent_id          — Per subagent/teammate (getAgentId())"
    echo "  parent_session_id — Links subagents to parent (getParentSessionId())"
    echo "  event.sequence    — Monotonically increasing event counter"
    echo "  interaction.seq   — Per-interaction sequence number"
    echo ""

    # Count span types
    echo -e "${BLUE}Span Types Defined:${NC}"
    grep -oE "'claude_code\.[^']+'" "$PROJECT_ROOT/src/utils/telemetry/sessionTracing.ts" 2>/dev/null | \
        sort -u | sed "s/'//g" | while read -r span; do
            echo "  $span"
        done
    echo ""

    # Span attributes
    echo -e "${BLUE}Key Span Attributes:${NC}"
    echo "  span.type          — interaction | llm_request | tool | tool.blocked_on_user | tool.execution | hook"
    echo "  tool_name          — Tool being executed"
    echo "  model              — LLM model used"
    echo "  duration_ms        — Span duration"
    echo "  input_tokens       — Prompt token count"
    echo "  output_tokens      — Completion token count"
    echo "  cache_read_tokens  — Tokens served from cache"
    echo "  cache_creation_tokens — Tokens written to cache"
    echo "  ttft_ms            — Time to first token"
    echo "  success            — Boolean success indicator"
    echo "  error              — Error message if failed"
    echo "  query_source       — Agent name triggering the request"
    echo "  speed              — fast | normal"
    echo "  attempt            — Retry attempt number"
}

# --- Command: ids ---
cmd_ids() {
    echo -e "${CYAN}=== Correlation ID Reference ===${NC}"
    echo ""

    echo -e "${BLUE}ID Sources in bootstrap/state.ts:${NC}"
    grep -n "SessionId\|PromptId\|AgentId\|ParentSession" \
        "$PROJECT_ROOT/src/bootstrap/state.ts" 2>/dev/null | \
        head -15 | sed 's/^/  /'
    echo ""

    echo -e "${BLUE}ID Generation:${NC}"
    echo "  Session ID:  getSessionId() -> UUID, stored per process"
    echo "  Prompt ID:   getPromptId() -> UUID, per user prompt cycle"
    echo "  User ID:     getOrCreateUserID() -> hash-based persistent ID"
    echo "  Account ID:  toTaggedId('user', <uuid>) -> user:<hash>"
    echo "  Agent ID:    getAgentId() -> session ID or subagent ID"
    echo "  Team Name:   getTeamName() -> agent team identifier"
    echo ""

    echo -e "${BLUE}ID Propagation:${NC}"
    echo "  1. Session ID -> telemetryAttributes -> all metrics/spans"
    echo "  2. Prompt ID  -> logOTelEvent -> event records"
    echo "  3. User ID    -> telemetryAttributes -> all signals"
    echo "  4. Agent ID   -> perfettoTracing -> trace events (pid field)"
    echo "  5. Parent ID  -> perfettoTracing -> metadata events"
    echo ""

    echo -e "${BLUE}ID in Datadog Tags:${NC}"
    grep -oE "'[^']+'" "$PROJECT_ROOT/src/services/analytics/datadog.ts" 2>/dev/null | \
        grep -iE "id|uuid|bucket|version" | sort -u | sed "s/'//g" | while read -r tag; do
            echo "  $tag"
        done
}

# --- Command: spans ---
cmd_spans() {
    echo -e "${CYAN}=== Span Hierarchy Model ===${NC}"
    echo ""

    echo -e "${BLUE}Span Tree:${NC}"
    echo ""
    echo "  interaction (root span)"
    echo "  ├── llm_request (child of interaction)"
    echo "  │   ├── Request Setup (Perfetto sub-span)"
    echo "  │   │   └── Attempt N (retry) (Perfetto sub-sub-span)"
    echo "  │   ├── First Token (Perfetto sub-span)"
    echo "  │   └── Sampling (Perfetto sub-span)"
    echo "  ├── tool (child of interaction)"
    echo "  │   ├── tool.blocked_on_user (child of tool)"
    echo "  │   └── tool.execution (child of tool)"
    echo "  ├── hook (child of interaction or tool)"
    echo "  └── Waiting for User Input (Perfetto standalone)"
    echo ""

    echo -e "${BLUE}Span Lifecycle Functions:${NC}"
    echo ""
    echo "  startInteractionSpan(userPrompt)"
    echo "    -> creates root span with telemetry attributes"
    echo "    -> sets AsyncLocalStorage context"
    echo ""
    echo "  startLLMRequestSpan(model, newContext?, messages?, fastMode?)"
    echo "    -> child of interaction (via ALS context)"
    echo "    -> adds model, query_source, beta attributes"
    echo ""
    echo "  endLLMRequestSpan(span?, metadata?)"
    echo "    -> adds duration, tokens, success, ttft_ms"
    echo "    -> specific span MUST be passed for parallel requests"
    echo ""
    echo "  startToolSpan(toolName, attributes?, input?)"
    echo "    -> child of interaction (via ALS context)"
    echo "    -> adds tool_name, beta input attributes"
    echo ""
    echo "  startToolBlockedOnUserSpan()"
    echo "    -> child of tool (via tool ALS context)"
    echo "    -> tracks permission wait time"
    echo ""
    echo "  endToolBlockedOnUserSpan(decision?, source?)"
    echo "    -> adds decision (accept/deny) and source"
    echo ""
    echo "  startToolExecutionSpan()"
    echo "    -> child of tool (via tool ALS context)"
    echo "    -> tracks actual execution time"
    echo ""
    echo "  startHookSpan(hookEvent, hookName, numHooks, definitions)"
    echo "    -> child of tool or interaction"
    echo "    -> beta tracing only"
    echo ""
    echo "  endInteractionSpan()"
    echo "    -> adds duration_ms, clears ALS context"
    echo ""

    echo -e "${BLUE}Context Propagation:${NC}"
    echo "  interactionContext: AsyncLocalStorage<SpanContext>"
    echo "  toolContext:       AsyncLocalStorage<SpanContext>"
    echo "  activeSpans:       Map<spanId, WeakRef<SpanContext>>"
    echo "  strongSpans:       Map<spanId, SpanContext>  (LLM, blocked, execution, hook)"
    echo ""

    echo -e "${BLUE}TTL / Cleanup:${NC}"
    echo "  SPAN_TTL_MS: 30 minutes"
    echo "  Cleanup interval: 60 seconds"
    echo "  Orphan eviction: automatic via setInterval"
}

# --- Command: correlate ---
cmd_correlate() {
    local session_id="${1:-}"
    if [ -z "$session_id" ]; then
        echo -e "${YELLOW}Usage: ./trace.sh correlate <session-id>${NC}"
        echo ""
        echo "Queries all correlated data for a given session ID."
        echo ""
        echo "Available sessions:"
        if [ -d "$TRACES_DIR" ]; then
            find "$TRACES_DIR" -name "trace-*.json" -type f 2>/dev/null | \
                sed 's/.*trace-//' | sed 's/\.json//' | while read -r id; do
                    echo "  $id"
                done
        else
            echo "  (no Perfetto traces found)"
        fi
        return
    fi

    echo -e "${CYAN}=== Correlation Query: $session_id ===${NC}"
    echo ""

    # Check Perfetto trace
    local trace_file="$TRACES_DIR/trace-${session_id}.json"
    if [ -f "$trace_file" ] && has_jq; then
        echo -e "${GREEN}Perfetto trace found${NC}"
        echo ""

        echo -e "${BLUE}Metadata:${NC}"
        jq '.metadata' "$trace_file" 2>/dev/null | sed 's/^/  /'
        echo ""

        echo -e "${BLUE}Agent hierarchy:${NC}"
        jq -r '.traceEvents[] | select(.cat == "__metadata") | select(.name == "process_name" or .name == "thread_name" or .name == "parent_agent") |
            "  pid=\(.pid) \(.name): \(.args.name // .args.parent_agent_id // "?")"' \
            "$trace_file" 2>/dev/null
        echo ""

        echo -e "${BLUE}Correlated API calls -> Tool calls:${NC}"
        # Find API calls and their associated tools within the same interaction
        jq -r '
            .traceEvents as $events |
            $events[] | select(.ph == "B") |
            .name as $span_name |
            .ts as $start_ts |
            select($span_name == "Interaction") |
            {start: $start_ts, name: $span_name}
        ' "$trace_file" 2>/dev/null | head -10
        echo ""

        echo -e "${BLUE}All events for this session (by timestamp):${NC}"
        jq -r '.traceEvents | sort_by(.ts) | .[] |
            "[\(.ts / 1000000 | floor)s] \(.ph) \(.name) [\(.cat)] \(if .args then (.args | to_entries | map("\(.key)=\(.value)") | join(" ")) else "" end)"' \
            "$trace_file" 2>/dev/null | head -40 | sed 's/^/  /'
    else
        echo -e "${YELLOW}No Perfetto trace file found for session $session_id${NC}"
        echo "  Expected: $trace_file"
    fi

    # Show what source code references for this session ID pattern
    echo ""
    echo -e "${BLUE}Session ID usage points in source (correlation points):${NC}"
    grep -rn "session.id\|sessionId\|getSessionId" \
        "$PROJECT_ROOT/src/utils/telemetry/" \
        "$PROJECT_ROOT/src/services/analytics/" \
        --include="*.ts" 2>/dev/null | head -15 | sed 's/^/  /'
}

# --- Command: hierarchy ---
cmd_hierarchy() {
    echo -e "${CYAN}=== Agent Hierarchy Model ===${NC}"
    echo ""

    echo -e "${BLUE}Teammate/Subagent Tracking:${NC}"
    echo ""
    echo "  Main Agent (pid=1)"
    echo "    session.id = main session UUID"
    echo "    agent_name = 'main'"
    echo ""
    echo "  Subagent 1 (pid=2)"
    echo "    agent_id = subagent UUID"
    echo "    agent_name = agent display name"
    echo "    parent_session_id = main session UUID"
    echo ""
    echo "  Subagent 2 (pid=3)"
    echo "    agent_id = subagent UUID"
    echo "    agent_name = agent display name"
    echo "    parent_session_id = main session UUID"
    echo ""

    echo -e "${BLUE}Hierarchy Source Functions:${NC}"
    grep -rn "getAgentId\|getAgentName\|getParentSessionId\|registerAgent\|unregisterAgent" \
        "$PROJECT_ROOT/src/utils/telemetry/perfettoTracing.ts" 2>/dev/null | \
        grep "^.*export\|^.*function" | sed 's/^/  /'
    echo ""

    echo -e "${BLUE}Perfetto Metadata Events:${NC}"
    echo "  process_name (ph: 'M') — Agent name for the process track"
    echo "  thread_name (ph: 'M') — Agent name for the thread track"
    echo "  parent_agent (ph: 'M') — Parent session ID for hierarchy"
    echo ""

    echo -e "${BLUE}ID Mapping:${NC}"
    echo "  agentId -> numeric processId (Perfetto requirement)"
    echo "  agentName -> numeric threadId (via djb2Hash)"
    echo "  agentIdToProcessId: Map<string, number>"
    echo "  agentRegistry: Map<string, AgentInfo>"
}

# --- Command: env ---
cmd_env() {
    echo -e "${CYAN}=== Tracing Environment Controls ===${NC}"
    echo ""

    echo -e "${BLUE}Standard OTEL Tracing:${NC}"
    echo "  CLAUDE_CODE_ENABLE_TELEMETRY=1           Enable OTEL SDK"
    echo "  CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1     Enable session tracing"
    echo "  OTEL_TRACES_EXPORTER=console|otlp          Trace exporter type"
    echo "  OTEL_EXPORTER_OTLP_TRACES_PROTOCOL         grpc|http/json|http/protobuf"
    echo "  OTEL_EXPORTER_OTLP_ENDPOINT                Collector URL"
    echo "  OTEL_EXPORTER_OTLP_HEADERS                 Auth headers (key=val,key=val)"
    echo "  OTEL_TRACES_EXPORT_INTERVAL                Batch delay (default: 5000ms)"
    echo ""

    echo -e "${BLUE}Beta Tracing (detailed):${NC}"
    echo "  ENABLE_BETA_TRACING_DETAILED=1            Enable detailed beta tracing"
    echo "  BETA_TRACING_ENDPOINT=<url>               Beta trace collector"
    echo ""

    echo -e "${BLUE}Perfetto Tracing:${NC}"
    echo "  CLAUDE_CODE_PERFETTO_TRACE=1              Enable (or set to custom path)"
    echo "  CLAUDE_CODE_PERFETTO_WRITE_INTERVAL_S=N   Periodic write interval"
    echo ""

    echo -e "${BLUE}Log Content Controls:${NC}"
    echo "  OTEL_LOG_USER_PROMPTS=1                   Include user prompt text in spans"
    echo "  OTEL_LOG_TOOL_CONTENT=1                   Include tool I/O content in spans"
    echo ""

    echo -e "${BLUE}Shutdown:${NC}"
    echo "  CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS      Force flush timeout (default: 2000ms)"
    echo ""

    echo -e "${BLUE}Privacy:${NC}"
    echo "  User prompts: REDACTED by default (<REDACTED> in spans)"
    echo "  Tool content: Not logged by default"
    echo "  Thinking output: External users: redacted. Ant: included"
    echo ""

    echo -e "${BLUE}Feature Gates (GrowthBook):${NC}"
    echo "  ENHANCED_TELEMETRY_BETA    — Controls enhanced telemetry"
    echo "  enhanced_telemetry_beta    — GrowthBook feature value"
    echo "  tengu_trace_lantern       — External user tracing gate"
    echo "  PERFETTO_TRACING          — Dead-code-eliminated for external builds"
}

# --- Command: validate ---
cmd_validate() {
    echo -e "${CYAN}=== Trace File Validation ===${NC}"
    echo ""

    if [ ! -d "$TRACES_DIR" ]; then
        echo -e "${YELLOW}No traces directory at $TRACES_DIR${NC}"
        return
    fi

    local trace_files
    trace_files=$(find "$TRACES_DIR" -name "trace-*.json" -type f 2>/dev/null)
    local trace_count
    trace_count=$(echo "$trace_files" | grep -c "." || echo "0")

    if [ "$trace_count" -eq 0 ]; then
        echo -e "${YELLOW}No trace files to validate${NC}"
        return
    fi

    echo "Validating $trace_count trace file(s)..."
    echo ""

    echo "$trace_files" | while read -r f; do
        local name
        name=$(basename "$f")

        if ! has_jq; then
            echo -e "  ${YELLOW}$name: Cannot validate without jq${NC}"
            continue
        fi

        local valid=true

        # Check it parses as JSON
        if ! jq empty "$f" 2>/dev/null; then
            echo -e "  ${RED}$name: Invalid JSON${NC}"
            continue
        fi

        # Check required top-level keys
        if [ "$(jq 'has("traceEvents")' "$f" 2>/dev/null)" != "true" ]; then
            echo -e "  ${RED}$name: Missing 'traceEvents' key${NC}"
            valid=false
        fi

        if [ "$(jq 'has("metadata")' "$f" 2>/dev/null)" != "true" ]; then
            echo -e "  ${YELLOW}$name: Missing 'metadata' key${NC}"
        fi

        # Check event format
        local event_count
        event_count=$(jq '.traceEvents | length' "$f" 2>/dev/null || echo "0")
        local valid_phases
        valid_phases=$(jq -r '.traceEvents[] | .ph' "$f" 2>/dev/null | \
            grep -cE '^(B|E|X|i|C|b|n|e|M)$' || echo "0")

        if [ "$valid_phases" -ne "$event_count" ]; then
            echo -e "  ${YELLOW}$name: Some events have invalid phase types ($valid_phases/$event_count)${NC}"
            valid=false
        fi

        # Check for matching B/E pairs (basic)
        local begin_count
        begin_count=$(jq '[.traceEvents[] | select(.ph == "B")] | length' "$f" 2>/dev/null || echo "0")
        local end_count
        end_count=$(jq '[.traceEvents[] | select(.ph == "E")] | length' "$f" 2>/dev/null || echo "0")

        if [ "$begin_count" -ne "$end_count" ]; then
            echo -e "  ${YELLOW}$name: Unmatched B/E pairs (B=$begin_count, E=$end_count)${NC}"
        fi

        if [ "$valid" = true ]; then
            echo -e "  ${GREEN}$name: Valid ($event_count events, B=$begin_count, E=$end_count)${NC}"
        fi
    done
}

# --- Command: inject-help ---
cmd_inject_help() {
    echo -e "${CYAN}=== Trace Context Injection Guide ===${NC}"
    echo ""

    echo "Open-ClaudeCode uses AsyncLocalStorage (ALS) for trace context propagation."
    echo "No manual injection is required in normal operation."
    echo ""

    echo -e "${BLUE}Automatic Context Propagation:${NC}"
    echo ""
    echo "  1. startInteractionSpan() -> sets interactionContext via enterWith()"
    echo "  2. startLLMRequestSpan()  -> reads parent from interactionContext"
    echo "  3. startToolSpan()        -> reads parent from interactionContext, sets toolContext"
    echo "  4. startHookSpan()        -> reads parent from toolContext || interactionContext"
    echo ""

    echo -e "${BLUE}For Testing / External Integration:${NC}"
    echo ""
    echo "  To enable telemetry for an external agent:"
    echo ""
    echo "    export CLAUDE_CODE_ENABLE_TELEMETRY=1"
    echo "    export OTEL_TRACES_EXPORTER=otlp"
    echo "    export OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318"
    echo "    export OTEL_EXPORTER_OTLP_PROTOCOL=http/json"
    echo ""

    echo "  To enable session tracing:"
    echo ""
    echo "    export CLAUDE_CODE_ENHANCED_TELEMETRY_BETA=1"
    echo ""

    echo "  To enable Perfetto traces:"
    echo ""
    echo "    export CLAUDE_CODE_PERFETTO_TRACE=1"
    echo "    # Optional: periodic writes"
    echo "    export CLAUDE_CODE_PERFETTO_WRITE_INTERVAL_S=30"
    echo ""

    echo -e "${BLUE}Span Attribute Injection (for developers):${NC}"
    echo ""
    echo "  Within a span, add custom attributes:"
    echo "    span.setAttribute('custom.key', 'value')"
    echo ""
    echo "  Via the OTel event system:"
    echo "    logOTelEvent('custom_event', { key: 'value' })"
    echo ""
    echo "  Via the analytics pipeline:"
    echo "    logEvent('tengu_custom_event', { numeric_field: 42, bool_field: true })"
}

# --- Main ---
COMMAND="${1:-summary}"
shift || true

case "$COMMAND" in
    summary)
        cmd_summary
        ;;
    ids)
        cmd_ids
        ;;
    spans)
        cmd_spans
        ;;
    correlate)
        cmd_correlate "${1:-}"
        ;;
    hierarchy)
        cmd_hierarchy
        ;;
    env)
        cmd_env
        ;;
    validate)
        cmd_validate
        ;;
    inject-help)
        cmd_inject_help
        ;;
    *)
        echo "Open-ClaudeCode Trace & Correlation Query"
        echo ""
        echo "Usage: ./trace.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  summary               Tracing infrastructure overview"
        echo "  ids                   List all correlation ID types"
        echo "  spans                 Show span hierarchy model"
        echo "  correlate <session>   Query correlated data for a session"
        echo "  hierarchy             Show agent hierarchy model"
        echo "  env                   Show tracing environment controls"
        echo "  validate              Validate Perfetto trace files"
        echo "  inject-help           Guide for trace context injection"
        ;;
esac
