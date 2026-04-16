#!/bin/bash
# =============================================================================
# Observability Agent Shell Script for Open-ClaudeCode
#
# A CLI-accessible script that an AI agent can run to gather observability
# data about a running or recent Open-ClaudeCode session. Reads from
# environment variables, config files, trace files, and log outputs.
#
# Usage:
#   ./observability-agent.sh [command]
#
# Commands:
#   health        - Run health checks against the project environment
#   telemetry     - Show current telemetry configuration
#   traces        - List and summarize available Perfetto trace files
#   session       - Show the most recent session's trace summary
#   env           - Dump all observability-relevant environment variables
#   diagnose      - Run full diagnostic and output a structured report
#   watch         - Continuously monitor trace file growth (like tail -f)
# =============================================================================

set -euo pipefail

# --- Configuration ---
CLAUDE_CONFIG_HOME="${CLAUDE_CONFIG_HOME:-$HOME/.claude}"
TRACES_DIR="${CLAUDE_CONFIG_HOME}/traces"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# --- Colors (respects NO_COLOR) ---
if [ -z "${NO_COLOR:-}" ] && [ -t 1 ]; then
  RED='\033[0;31m'
  YELLOW='\033[1;33m'
  GREEN='\033[0;32m'
  CYAN='\033[0;36m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED='' YELLOW='' GREEN='' CYAN='' BOLD='' RESET=''
fi

# --- Helper functions ---

json_output() {
  # If --json flag is set, output raw JSON; otherwise pretty-print
  if [ "${OUTPUT_JSON:-}" = "1" ]; then
    cat
  else
    # Try to use jq for pretty printing, fall back to cat
    if command -v jq &>/dev/null; then
      jq .
    else
      cat
    fi
  fi
}

status_icon() {
  case "$1" in
    pass|healthy|ok|true|yes)  echo -e "${GREEN}[PASS]${RESET}" ;;
    warn|degraded)             echo -e "${YELLOW}[WARN]${RESET}" ;;
    fail|error|false|no|*)     echo -e "${RED}[FAIL]${RESET}" ;;
  esac
}

# --- Commands ---

cmd_health() {
  echo -e "${BOLD}=== Health Check ===${RESET} (${TIMESTAMP})"
  echo ""

  local PASS=0
  local WARN=0
  local FAIL=0

  # Check 1: Node.js version
  if command -v node &>/dev/null; then
    NODE_VERSION=$(node --version)
    NODE_MAJOR=$(echo "$NODE_VERSION" | sed 's/v//' | cut -d. -f1)
    if [ "$NODE_MAJOR" -ge 20 ]; then
      echo "$(status_icon pass) Node.js: ${NODE_VERSION} (>= v20)"
      PASS=$((PASS + 1))
    elif [ "$NODE_MAJOR" -ge 18 ]; then
      echo "$(status_icon warn) Node.js: ${NODE_VERSION} (>= v18 but < v20)"
      WARN=$((WARN + 1))
    else
      echo "$(status_icon fail) Node.js: ${NODE_VERSION} (below minimum v18)"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "$(status_icon fail) Node.js: not found"
    FAIL=$((FAIL + 1))
  fi

  # Check 2: Config directory
  if [ -d "$CLAUDE_CONFIG_HOME" ]; then
    echo "$(status_icon pass) Config dir: ${CLAUDE_CONFIG_HOME} exists"
    PASS=$((PASS + 1))

    # Check writability
    if touch "$CLAUDE_CONFIG_HOME/.health-check-tmp" 2>/dev/null && \
       rm "$CLAUDE_CONFIG_HOME/.health-check-tmp" 2>/dev/null; then
      echo "$(status_icon pass) Config dir: writable"
      PASS=$((PASS + 1))
    else
      echo "$(status_icon fail) Config dir: not writable"
      FAIL=$((FAIL + 1))
    fi
  else
    echo "$(status_icon fail) Config dir: ${CLAUDE_CONFIG_HOME} not found"
    FAIL=$((FAIL + 1))
  fi

  # Check 3: Traces directory
  if [ -d "$TRACES_DIR" ]; then
    TRACE_COUNT=$(find "$TRACES_DIR" -name "trace-*.json" 2>/dev/null | wc -l | tr -d ' ')
    echo "$(status_icon pass) Traces dir: ${TRACE_COUNT} trace files"
    PASS=$((PASS + 1))
  else
    echo "$(status_icon warn) Traces dir: ${TRACES_DIR} does not exist"
    WARN=$((WARN + 1))
  fi

  # Check 4: Auth
  if [ -n "${ANTHROPIC_API_KEY:-}" ]; then
    echo "$(status_icon pass) Auth: API key set (${#ANTHROPIC_API_KEY} chars)"
    PASS=$((PASS + 1))
  elif [ -n "${CLAUDE_CODE_OAUTH_TOKEN:-}" ]; then
    echo "$(status_icon pass) Auth: OAuth token set"
    PASS=$((PASS + 1))
  else
    echo "$(status_icon warn) Auth: no API key or OAuth token in environment"
    WARN=$((WARN + 1))
  fi

  # Check 5: API connectivity
  if command -v curl &>/dev/null; then
    API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
      "https://api.anthropic.com/api/health" 2>/dev/null || echo "000")
    if [ "$API_STATUS" = "200" ] || [ "$API_STATUS" = "404" ]; then
      # 404 is ok — the endpoint may not exist but the host is reachable
      echo "$(status_icon pass) API: reachable (HTTP ${API_STATUS})"
      PASS=$((PASS + 1))
    elif [ "$API_STATUS" = "000" ]; then
      echo "$(status_icon fail) API: unreachable (timeout/error)"
      FAIL=$((FAIL + 1))
    else
      echo "$(status_icon warn) API: HTTP ${API_STATUS}"
      WARN=$((WARN + 1))
    fi
  else
    echo "$(status_icon warn) API: curl not available, skipping"
    WARN=$((WARN + 1))
  fi

  # Check 6: Process memory (if a claude-code process is running)
  if command -v ps &>/dev/null; then
    CC_PID=$(pgrep -f "claude" 2>/dev/null | head -1 || true)
    if [ -n "$CC_PID" ]; then
      # macOS and Linux have different ps output
      if [ "$(uname)" = "Darwin" ]; then
        RSS=$(ps -o rss= -p "$CC_PID" 2>/dev/null || echo "0")
      else
        RSS=$(ps -o rss= -p "$CC_PID" 2>/dev/null || echo "0")
      fi
      RSS_MB=$((RSS / 1024))
      if [ "$RSS_MB" -gt 2048 ]; then
        echo "$(status_icon fail) Process memory: ${RSS_MB}MB RSS (exceeds 2GB)"
        FAIL=$((FAIL + 1))
      elif [ "$RSS_MB" -gt 1024 ]; then
        echo "$(status_icon warn) Process memory: ${RSS_MB}MB RSS (high)"
        WARN=$((WARN + 1))
      else
        echo "$(status_icon pass) Process memory: ${RSS_MB}MB RSS"
        PASS=$((PASS + 1))
      fi
    else
      echo "$(status_icon warn) Process: no running claude process detected"
      WARN=$((WARN + 1))
    fi
  fi

  echo ""
  echo -e "Summary: ${GREEN}${PASS} pass${RESET}, ${YELLOW}${WARN} warn${RESET}, ${RED}${FAIL} fail${RESET}"

  if [ "$FAIL" -gt 0 ]; then
    return 1
  fi
  return 0
}

cmd_telemetry() {
  echo -e "${BOLD}=== Telemetry Configuration ===${RESET} (${TIMESTAMP})"
  echo ""

  echo -e "${CYAN}OpenTelemetry:${RESET}"
  echo "  CLAUDE_CODE_ENABLE_TELEMETRY: ${CLAUDE_CODE_ENABLE_TELEMETRY:-<not set>}"
  echo "  OTEL_EXPORTER_OTLP_ENDPOINT: ${OTEL_EXPORTER_OTLP_ENDPOINT:-<not set>}"
  echo "  OTEL_EXPORTER_OTLP_PROTOCOL: ${OTEL_EXPORTER_OTLP_PROTOCOL:-<not set>}"
  echo "  OTEL_METRICS_EXPORTER:       ${OTEL_METRICS_EXPORTER:-<not set>}"
  echo "  OTEL_LOGS_EXPORTER:          ${OTEL_LOGS_EXPORTER:-<not set>}"
  echo "  OTEL_TRACES_EXPORTER:        ${OTEL_TRACES_EXPORTER:-<not set>}"
  echo "  OTEL_METRIC_EXPORT_INTERVAL: ${OTEL_METRIC_EXPORT_INTERVAL:-<default 60000ms>}"
  echo "  OTEL_LOGS_EXPORT_INTERVAL:   ${OTEL_LOGS_EXPORT_INTERVAL:-<default 5000ms>}"
  echo "  OTEL_TRACES_EXPORT_INTERVAL: ${OTEL_TRACES_EXPORT_INTERVAL:-<default 5000ms>}"
  echo "  OTEL_EXPORTER_OTLP_HEADERS:  $([ -n "${OTEL_EXPORTER_OTLP_HEADERS:-}" ] && echo '<set, redacted>' || echo '<not set>')"

  echo ""
  echo -e "${CYAN}Enhanced Telemetry:${RESET}"
  echo "  ENABLE_ENHANCED_TELEMETRY_BETA:    ${ENABLE_ENHANCED_TELEMETRY_BETA:-<not set>}"
  echo "  CLAUDE_CODE_ENHANCED_TELEMETRY_BETA: ${CLAUDE_CODE_ENHANCED_TELEMETRY_BETA:-<not set>}"

  echo ""
  echo -e "${CYAN}Perfetto Tracing:${RESET}"
  echo "  CLAUDE_CODE_PERFETTO_TRACE:          ${CLAUDE_CODE_PERFETTO_TRACE:-<not set>}"
  echo "  CLAUDE_CODE_PERFETTO_WRITE_INTERVAL_S: ${CLAUDE_CODE_PERFETTO_WRITE_INTERVAL_S:-<not set>}"

  echo ""
  echo -e "${CYAN}Beta Tracing:${RESET}"
  echo "  BETA_TRACING_ENDPOINT: ${BETA_TRACING_ENDPOINT:-<not set>}"

  echo ""
  echo -e "${CYAN}Shutdown:${RESET}"
  echo "  CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS: ${CLAUDE_CODE_OTEL_SHUTDOWN_TIMEOUT_MS:-<default 2000ms>}"
  echo "  CLAUDE_CODE_OTEL_FLUSH_TIMEOUT_MS:    ${CLAUDE_CODE_OTEL_FLUSH_TIMEOUT_MS:-<default 5000ms>}"

  echo ""
  echo -e "${CYAN}Content Logging:${RESET}"
  echo "  OTEL_LOG_USER_PROMPTS:   ${OTEL_LOG_USER_PROMPTS:-<not set>}"
  echo "  OTEL_LOG_TOOL_CONTENT:   ${OTEL_LOG_TOOL_CONTENT:-<not set>}"
  echo "  OTEL_LOG_TOOL_DETAILS:   ${OTEL_LOG_TOOL_DETAILS:-<not set>}"

  echo ""
  echo -e "${CYAN}Datadog:${RESET}"
  echo "  CLAUDE_CODE_DATADOG_FLUSH_INTERVAL_MS: ${CLAUDE_CODE_DATADOG_FLUSH_INTERVAL_MS:-<default 15000ms>}"

  echo ""
  echo -e "${CYAN}Identity:${RESET}"
  echo "  USER_TYPE:               ${USER_TYPE:-<not set>}"
  echo "  CLAUDE_CODE_SESSION_ID:  ${CLAUDE_CODE_SESSION_ID:-<not set>}"
  echo "  CLAUDE_CODE_AGENT_ID:    ${CLAUDE_CODE_AGENT_ID:-<not set>}"
}

cmd_traces() {
  echo -e "${BOLD}=== Perfetto Trace Files ===${RESET} (${TIMESTAMP})"
  echo ""

  if [ ! -d "$TRACES_DIR" ]; then
    echo "No traces directory found at: ${TRACES_DIR}"
    return 0
  fi

  TRACE_FILES=$(find "$TRACES_DIR" -name "trace-*.json" -type f 2>/dev/null | sort)
  if [ -z "$TRACE_FILES" ]; then
    echo "No trace files found in: ${TRACES_DIR}"
    return 0
  fi

  echo "Directory: ${TRACES_DIR}"
  echo ""

  for f in $TRACE_FILES; do
    FILENAME=$(basename "$f")
    FILESIZE=$(du -h "$f" 2>/dev/null | cut -f1)
    MODIFIED=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "$f" 2>/dev/null || \
               stat -c "%y" "$f" 2>/dev/null | cut -d. -f1 || \
               echo "unknown")

    # Try to extract session ID and event count from trace
    if command -v jq &>/dev/null; then
      EVENT_COUNT=$(jq '.traceEvents | length' "$f" 2>/dev/null || echo "?")
      SESSION_ID=$(jq -r '.metadata.session_id // "unknown"' "$f" 2>/dev/null || echo "?")
      AGENT_COUNT=$(jq -r '.metadata.agent_count // "1"' "$f" 2>/dev/null || echo "?")
    else
      EVENT_COUNT="?"
      SESSION_ID="?"
      AGENT_COUNT="?"
    fi

    echo -e "  ${CYAN}${FILENAME}${RESET}"
    echo "    Size: ${FILESIZE}  Modified: ${MODIFIED}"
    echo "    Session: ${SESSION_ID}  Events: ${EVENT_COUNT}  Agents: ${AGENT_COUNT}"
    echo ""
  done

  TOTAL_SIZE=$(du -sh "$TRACES_DIR" 2>/dev/null | cut -f1 || echo "unknown")
  TOTAL_FILES=$(echo "$TRACE_FILES" | wc -l | tr -d ' ')
  echo "Total: ${TOTAL_FILES} trace files, ${TOTAL_SIZE}"
}

cmd_session() {
  echo -e "${BOLD}=== Latest Session Trace ===${RESET}"
  echo ""

  if [ ! -d "$TRACES_DIR" ]; then
    echo "No traces directory found."
    return 1
  fi

  LATEST_TRACE=$(find "$TRACES_DIR" -name "trace-*.json" -type f -exec stat -f "%m %N" {} \; 2>/dev/null | \
    sort -rn | head -1 | cut -d' ' -f2 || \
    find "$TRACES_DIR" -name "trace-*.json" -type f -printf '%T@ %p\n' 2>/dev/null | \
    sort -rn | head -1 | cut -d' ' -f2)

  if [ -z "$LATEST_TRACE" ] || [ ! -f "$LATEST_TRACE" ]; then
    echo "No trace files found."
    return 1
  fi

  echo "File: ${LATEST_TRACE}"
  echo ""

  if ! command -v jq &>/dev/null; then
    echo "Install jq for detailed trace analysis."
    cat "$LATEST_TRACE" | head -50
    return 0
  fi

  # Extract summary metrics
  echo -e "${CYAN}Session Metadata:${RESET}"
  jq -r '.metadata | to_entries[] | "  \(.key): \(.value)"' "$LATEST_TRACE" 2>/dev/null

  echo ""
  echo -e "${CYAN}Span Type Distribution:${RESET}"
  jq -r '.traceEvents | group_by(.name) | map({name: .[0].name, count: length}) | sort_by(-.count) | .[] | "  \(.name): \(.count)"' "$LATEST_TRACE" 2>/dev/null

  echo ""
  echo -e "${CYAN}API Call Performance:${RESET}"
  jq -r '.traceEvents | map(select(.name == "API Call" and .ph == "E")) |
    map(.args) |
    if length > 0 then
      "  Count: \(length)",
      "  Avg duration: \((map(.duration_ms) | add / length) * 100 | round / 100)ms",
      "  Max duration: \((map(.duration_ms) | max) * 100 | round / 100)ms",
      "  Avg TTFT: \((map(select(.ttft_ms != null) | .ttft_ms) | add / length) * 100 | round / 100)ms",
      "  Errors: \(map(select(.success == false)) | length)"
    else
      "  No API call spans found"
    end' "$LATEST_TRACE" 2>/dev/null

  echo ""
  echo -e "${CYAN}Tool Calls:${RESET}"
  jq -r '.traceEvents | map(select((.name // "") | startswith("Tool:") and .ph == "E")) |
    group_by(.name) |
    map({name: .[0].name, count: length, avg_duration: (map(.args.duration_ms) | add / length)}) |
    sort_by(-.count) |
    .[] |
    "  \(.name): \(.count) calls, avg \((.avg_duration * 100 | round / 100))ms"' "$LATEST_TRACE" 2>/dev/null
}

cmd_env() {
  echo -e "${BOLD}=== Observability Environment ===${RESET} (${TIMESTAMP})"
  echo ""

  # List all relevant env vars, masking sensitive values
  env | grep -E '^(OTEL|CLAUDE_CODE|ANTHROPIC|USER_TYPE|BETA_TRACING|CLAUDE_CODE_PERFETTO|ENABLE_ENHANCED)' | \
    while IFS= read -r line; do
      KEY=$(echo "$line" | cut -d= -f1)
      VALUE=$(echo "$line" | cut -d= -f2-)

      # Mask sensitive values
      case "$KEY" in
        *API_KEY*|*TOKEN*|*SECRET*|*PASSWORD*|OTEL_EXPORTER_OTLP_HEADERS)
          echo "  ${KEY}=<${#VALUE} chars, redacted>"
          ;;
        *)
          echo "  ${KEY}=${VALUE}"
          ;;
      esac
    done
}

cmd_diagnose() {
  echo -e "${BOLD}=== Full Diagnostic ===${RESET}"
  echo ""
  cmd_health
  echo ""
  echo "----------------------------------------"
  echo ""
  cmd_telemetry
  echo ""
  echo "----------------------------------------"
  echo ""
  cmd_session 2>/dev/null || echo "No session traces available."
  echo ""
  echo "----------------------------------------"
  echo ""
  cmd_env
}

cmd_watch() {
  echo -e "${BOLD}=== Watching Trace Directory ===${RESET}"
  echo "Monitoring: ${TRACES_DIR}"
  echo "Press Ctrl+C to stop."
  echo ""

  if [ ! -d "$TRACES_DIR" ]; then
    echo "Creating traces directory: ${TRACES_DIR}"
    mkdir -p "$TRACES_DIR"
  fi

  # Use fswatch if available, otherwise poll
  if command -v fswatch &>/dev/null; then
    fswatch --event Updated --event Created "$TRACES_DIR" | while read -r changed_file; do
      echo "[${TIMESTAMP}] Changed: ${changed_file}"
      FILESIZE=$(du -h "$changed_file" 2>/dev/null | cut -f1 || echo "?")
      echo "  Size: ${FILESIZE}"
    done
  else
    echo "fswatch not found. Polling every 5 seconds..."
    LAST_COUNT=$(find "$TRACES_DIR" -name "trace-*.json" 2>/dev/null | wc -l)
    while true; do
      sleep 5
      CURRENT_COUNT=$(find "$TRACES_DIR" -name "trace-*.json" 2>/dev/null | wc -l)
      if [ "$CURRENT_COUNT" -ne "$LAST_COUNT" ]; then
        echo "[${TIMESTAMP}] Trace file count changed: ${LAST_COUNT} -> ${CURRENT_COUNT}"
        LAST_COUNT=$CURRENT_COUNT
      fi
    done
  fi
}

# --- Main ---

COMMAND="${1:-diagnose}"

case "$COMMAND" in
  health)     cmd_health ;;
  telemetry)  cmd_telemetry ;;
  traces)     cmd_traces ;;
  session)    cmd_session ;;
  env)        cmd_env ;;
  diagnose)   cmd_diagnose ;;
  watch)      cmd_watch ;;
  *)
    echo "Usage: $0 {health|telemetry|traces|session|env|diagnose|watch}"
    echo ""
    echo "Commands:"
    echo "  health      - Run health checks"
    echo "  telemetry   - Show telemetry configuration"
    echo "  traces      - List trace files"
    echo "  session     - Summarize latest session trace"
    echo "  env         - Show observability env vars"
    echo "  diagnose    - Run full diagnostic (default)"
    echo "  watch       - Monitor trace directory for changes"
    exit 1
    ;;
esac
