#!/bin/bash
# scaffold/instrument-tool-lifecycle.sh
# Analyzes tool files and generates instrumentation points for lifecycle events.
# Creates a report of where to add lifecycle hooks for: start, progress, error, complete.
# Does NOT modify source files - generates an instrumentation plan.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
SRC_DIR="${PROJECT_ROOT}/src"
OUTPUT_DIR="${PROJECT_ROOT}/.scaffolding/observability"

mkdir -p "$OUTPUT_DIR"

echo "=== Tool Lifecycle Instrumentation Analyzer ==="
echo ""

PLAN_FILE="${OUTPUT_DIR}/tool-instrumentation-plan.txt"
: > "$PLAN_FILE"

TOOLS_PROCESSED=0
INSTRUMENTATION_POINTS=0

# Analyze a single tool file
analyze_tool() {
    local file="$1"
    local relpath="${file#"$SRC_DIR/"}"
    local tool_name
    tool_name=$(basename "$(dirname "$file")")

    TOOLS_PROCESSED=$((TOOLS_PROCESSED + 1))

    echo "=== ${tool_name} (${relpath}) ===" >> "$PLAN_FILE"

    # Point 1: Tool call entry (start event)
    if grep -qE "(async\s+call|call\s*:\s*async)" "$file" 2>/dev/null; then
        local call_line
        call_line=$(grep -nE "(async\s+call|call\s*:\s*async)" "$file" 2>/dev/null | head -1 | cut -d: -f1)
        if [[ -n "$call_line" ]]; then
            echo "  [START] Line ${call_line}: Add toolStart('${tool_name}') before call body" >> "$PLAN_FILE"
            INSTRUMENTATION_POINTS=$((INSTRUMENTATION_POINTS + 1))
        fi
    fi

    # Point 2: Error handling (error event)
    local catch_count
    catch_count=$(grep -cE "catch\s*\(" "$file" 2>/dev/null || echo "0")
    if [[ "$catch_count" -gt 0 ]]; then
        local catch_lines
        catch_lines=$(grep -nE "catch\s*\(" "$file" 2>/dev/null | cut -d: -f1 | tr '\n' ',')
        echo "  [ERROR] Lines ${catch_lines}: Add toolError('${tool_name}', error) in catch blocks" >> "$PLAN_FILE"
        INSTRUMENTATION_POINTS=$((INSTRUMENTATION_POINTS + 1))
    fi

    # Point 3: Return points (complete event)
    local return_count
    return_count=$(grep -cE "^\s*return\s+" "$file" 2>/dev/null || echo "0")
    if [[ "$return_count" -gt 0 ]]; then
        echo "  [COMPLETE] ${return_count} return statement(s): Add toolComplete('${tool_name}', result) before returns" >> "$PLAN_FILE"
        INSTRUMENTATION_POINTS=$((INSTRUMENTATION_POINTS + 1))
    fi

    # Point 4: Progress reporting (for long-running tools)
    if grep -qE "(BashTool|AgentTool|FileEditTool|WebFetchTool)" "$file" 2>/dev/null; then
        echo "  [PROGRESS] Long-running tool: Consider adding toolProgress('${tool_name}', {stage, pct}) callbacks" >> "$PLAN_FILE"
        INSTRUMENTATION_POINTS=$((INSTRUMENTATION_POINTS + 1))
    fi

    # Point 5: Duration tracking
    echo "  [TIMING] Wrap call body: const t0 = performance.now(); ... toolTiming('${tool_name}', t0)" >> "$PLAN_FILE"
    INSTRUMENTATION_POINTS=$((INSTRUMENTATION_POINTS + 1))

    echo "" >> "$PLAN_FILE"
}

echo "Scanning tool directories..."

# Process all tool directories
while IFS= read -r -d '' dir; do
    tool_name=$(basename "$dir")
    [[ "$tool_name" == "shared" ]] && continue
    [[ "$tool_name" == "testing" ]] && continue

    main_file="${dir}/${tool_name}.ts"
    if [[ -f "$main_file" ]]; then
        analyze_tool "$main_file"
    else
        # Find the first non-UI, non-prompt .ts file
        for f in "${dir}"/*.ts; do
            [[ -f "$f" ]] || continue
            local_name=$(basename "$f")
            if [[ "$local_name" != "UI.tsx" ]] && [[ "$local_name" != "prompt.ts" ]]; then
                analyze_tool "$f"
                break
            fi
        done
    fi
done < <(find "$SRC_DIR/tools" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

# Generate instrumentation template
TEMPLATE_FILE="${OUTPUT_DIR}/tool-lifecycle-template.ts"
cat > "$TEMPLATE_FILE" << 'TEMPLATE'
// Tool Lifecycle Instrumentation Template
// Add this to src/services/observability/toolLifecycle.ts

export interface ToolLifecycleEvent {
  toolName: string;
  event: 'start' | 'progress' | 'error' | 'complete';
  timestamp: number;
  sessionId: string;
  duration?: number;
  error?: Error;
  metadata?: Record<string, unknown>;
}

type ToolLifecycleListener = (event: ToolLifecycleEvent) => void;

class ToolLifecycleBus {
  private listeners: ToolLifecycleListener[] = [];
  private eventLog: ToolLifecycleEvent[] = [];
  private activeTools: Map<string, number> = new Map(); // toolName -> startTime

  subscribe(listener: ToolLifecycleListener): () => void {
    this.listeners.push(listener);
    return () => {
      this.listeners = this.listeners.filter(l => l !== listener);
    };
  }

  emit(event: Omit<ToolLifecycleEvent, 'timestamp'>): void {
    const fullEvent: ToolLifecycleEvent = {
      ...event,
      timestamp: Date.now(),
    };
    this.eventLog.push(fullEvent);
    for (const listener of this.listeners) {
      try { listener(fullEvent); } catch { /* swallow */ }
    }
  }

  start(toolName: string, sessionId: string, metadata?: Record<string, unknown>): void {
    this.activeTools.set(toolName, Date.now());
    this.emit({ toolName, event: 'start', sessionId, metadata });
  }

  progress(toolName: string, sessionId: string, metadata?: Record<string, unknown>): void {
    this.emit({ toolName, event: 'progress', sessionId, metadata });
  }

  error(toolName: string, sessionId: string, error: Error): void {
    const startTime = this.activeTools.get(toolName);
    const duration = startTime ? Date.now() - startTime : undefined;
    this.activeTools.delete(toolName);
    this.emit({ toolName, event: 'error', sessionId, error, duration });
  }

  complete(toolName: string, sessionId: string, metadata?: Record<string, unknown>): void {
    const startTime = this.activeTools.get(toolName);
    const duration = startTime ? Date.now() - startTime : undefined;
    this.activeTools.delete(toolName);
    this.emit({ toolName, event: 'complete', sessionId, duration, metadata });
  }

  getEventLog(): ToolLifecycleEvent[] {
    return [...this.eventLog];
  }

  getActiveTools(): string[] {
    return [...this.activeTools.keys()];
  }

  clearLog(): void {
    this.eventLog = [];
  }
}

// Singleton
export const toolLifecycle = new ToolLifecycleBus();

// Convenience functions for instrumentation
export function toolStart(name: string, sessionId: string, meta?: Record<string, unknown>) {
  if (process.env.CLAUDE_TOOL_LIFECYCLE !== '0') {
    toolLifecycle.start(name, sessionId, meta);
  }
}

export function toolError(name: string, sessionId: string, error: Error) {
  if (process.env.CLAUDE_TOOL_LIFECYCLE !== '0') {
    toolLifecycle.error(name, sessionId, error);
  }
}

export function toolComplete(name: string, sessionId: string, meta?: Record<string, unknown>) {
  if (process.env.CLAUDE_TOOL_LIFECYCLE !== '0') {
    toolLifecycle.complete(name, sessionId, meta);
  }
}
TEMPLATE

echo "  Tools processed: ${TOOLS_PROCESSED}"
echo "  Instrumentation points identified: ${INSTRUMENTATION_POINTS}"
echo ""
echo "Artifacts:"
echo "  Plan: ${PLAN_FILE}"
echo "  Template: ${TEMPLATE_FILE}"
echo ""
echo "PASSED: Instrumentation analysis complete"
exit 0
