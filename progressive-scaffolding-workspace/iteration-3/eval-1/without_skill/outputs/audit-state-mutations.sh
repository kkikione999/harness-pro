#!/bin/bash
# scaffold/audit-state-mutations.sh
# Analyzes AppState management and generates an audit logging plan.
# Identifies all state mutation paths and creates instrumentation templates.
# Does NOT modify source files - generates analysis and templates.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}"
SRC_DIR="${PROJECT_ROOT}/src"
OUTPUT_DIR="${PROJECT_ROOT}/.scaffolding/observability"

mkdir -p "$OUTPUT_DIR"

echo "=== State Mutation Audit Analyzer ==="
echo ""

PLAN_FILE="${OUTPUT_DIR}/state-audit-plan.txt"
TEMPLATE_FILE="${OUTPUT_DIR}/state-audit-template.ts"

{
    echo "State Mutation Audit Instrumentation Plan"
    echo "=========================================="
    echo ""

    # Analyze state type definition
    echo "--- 1. AppState Type (src/state/AppStateStore.ts) ---"
    if [[ -f "$SRC_DIR/state/AppStateStore.ts" ]]; then
        lines=$(wc -l < "$SRC_DIR/state/AppStateStore.ts" | tr -d ' ')
        echo "  File: ${lines} lines"

        # Find type fields
        echo "  State fields:"
        grep -oE "^\s+\w+(\??):\s+" "$SRC_DIR/state/AppStateStore.ts" 2>/dev/null | head -30 | sed 's/^/    /'

        echo ""
        echo "  Key mutations to audit:"
        # Find setState patterns
        echo "  - setState() calls (direct state changes)"
        echo "  - Store methods that modify state"
    fi
    echo ""

    # Analyze store implementation
    echo "--- 2. Store Implementation (src/state/store.ts) ---"
    if [[ -f "$SRC_DIR/state/store.ts" ]]; then
        lines=$(wc -l < "$SRC_DIR/state/store.ts" | tr -d ' ')
        echo "  File: ${lines} lines"
        echo "  Factory: createStore() with getState()/setState()"
        echo "  Audit point: Wrap setState to log mutations"
    fi
    echo ""

    # Analyze selector usage
    echo "--- 3. Selectors (src/state/selectors.ts) ---"
    if [[ -f "$SRC_DIR/state/selectors.ts" ]]; then
        lines=$(wc -l < "$SRC_DIR/state/selectors.ts" | tr -d ' ')
        echo "  File: ${lines} lines"
        echo "  Read-only: No audit needed (selectors don't mutate)"
    fi
    echo ""

    # Find all files that import from state
    echo "--- 4. State Consumers (files importing from state/) ---"
    state_importers=0
    while IFS= read -r -d '' file; do
        if grep -qE "from\s+['\"].*state/(AppState|AppStateStore|store)" "$file" 2>/dev/null; then
            relpath="${file#"$SRC_DIR/"}"
            # Check if this file calls setState or modifies state
            if grep -qE "setState|\.set\(|\.dispatch" "$file" 2>/dev/null; then
                echo "  MUTATION SOURCE: ${relpath}"
                state_importers=$((state_importers + 1))
            fi
        fi
    done < <(find "$SRC_DIR" -name "*.ts" -o -name "*.tsx" -print0 2>/dev/null)
    echo "  Total mutation sources found: ${state_importers}"
    echo ""

    # Analyze hooks that read/write state
    echo "--- 5. State-Connected Hooks ---"
    state_hooks=0
    while IFS= read -r -d '' file; do
        if grep -qE "useAppState|AppStoreContext" "$file" 2>/dev/null; then
            relpath="${file#"$SRC_DIR/"}"
            echo "  HOOK: ${relpath}"
            state_hooks=$((state_hooks + 1))
        fi
    done < <(find "$SRC_DIR/hooks" -name "*.ts" -o -name "*.tsx" -print0 2>/dev/null | head -20)
    echo "  State-connected hooks: ${state_hooks} (showing first 20)"
    echo ""

    # Audit strategy
    echo "=== Audit Strategy ==="
    echo ""
    echo "Approach: Wrap the Zustand-like store's setState method"
    echo ""
    echo "Key audit points:"
    echo "  1. src/state/store.ts - createStore() wrapper"
    echo "     Add: Before each setState, deep-diff old vs new state"
    echo "  2. src/state/AppState.tsx - AppStateProvider"
    echo "     Add: onChangeAppState callback for audit logging"
    echo "  3. src/state/onChangeAppState.ts - Existing callback handler"
    echo "     Extend: Add structured logging of state changes"
    echo ""
    echo "Environment control:"
    echo "  CLAUDE_STATE_AUDIT=1 enables audit logging"
    echo  "  CLAUDE_STATE_AUDIT_FIELDS=messages,tools enables field filtering"
    echo ""
    echo "Output format (JSON lines to stderr or file):"
    echo '  {"ts":...,"field":"messages","op":"set","oldLen":5,"newLen":6,"caller":"QueryEngine.ts:142"}'

} > "$PLAN_FILE"

# Generate audit template
cat > "$TEMPLATE_FILE" << 'TEMPLATE'
// State Mutation Audit Template
// Add this to src/services/observability/stateAudit.ts

type DeepPartial<T> = T extends object ? { [P in keyof T]?: DeepPartial<T[P]> } : T;

export interface StateMutationRecord {
  timestamp: number;
  field: string;
  operation: 'set' | 'merge' | 'delete' | 'array_push' | 'array_splice';
  oldValue?: unknown;
  newValue?: unknown;
  caller: string; // file:line of the setState call
  sessionId: string;
}

class StateAuditLog {
  private enabled: boolean;
  private fieldFilter: Set<string> | null = null;
  private log: StateMutationRecord[] = [];
  private maxLogSize = 10000;

  constructor() {
    this.enabled = process.env.CLAUDE_STATE_AUDIT === '1';
    const fields = process.env.CLAUDE_STATE_AUDIT_FIELDS;
    if (fields) {
      this.fieldFilter = new Set(fields.split(','));
    }
  }

  isEnabled(): boolean { return this.enabled; }

  /**
   * Record a state mutation. Called from wrapped setState.
   */
  record(
    field: string,
    operation: StateMutationRecord['operation'],
    oldValue: unknown,
    newValue: unknown,
    caller: string,
    sessionId: string
  ): void {
    if (!this.enabled) return;
    if (this.fieldFilter && !this.fieldFilter.has(field)) return;

    const record: StateMutationRecord = {
      timestamp: Date.now(),
      field,
      operation,
      oldValue: this.sanitize(oldValue),
      newValue: this.sanitize(newValue),
      caller,
      sessionId,
    };

    this.log.push(record);

    // Trim if too large
    if (this.log.length > this.maxLogSize) {
      this.log = this.log.slice(-this.maxLogSize / 2);
    }

    // Write to stderr for capture by external tools
    if (typeof process.stderr.write === 'function') {
      process.stderr.write(`[state-audit] ${JSON.stringify(record)}\n`);
    }
  }

  /**
   * Diff two state objects and record changes.
   */
  diffAndRecord(
    oldState: Record<string, unknown>,
    newState: Record<string, unknown>,
    caller: string,
    sessionId: string
  ): void {
    if (!this.enabled) return;

    const allKeys = new Set([...Object.keys(oldState), ...Object.keys(newState)]);
    for (const key of allKeys) {
      if (oldState[key] !== newState[key]) {
        this.record(key, 'set', oldState[key], newState[key], caller, sessionId);
      }
    }
  }

  private sanitize(value: unknown): unknown {
    if (value === undefined) return undefined;
    if (value === null) return null;
    if (typeof value === 'string') return value.length > 200 ? value.slice(0, 200) + '...' : value;
    if (typeof value === 'number' || typeof value === 'boolean') return value;
    if (Array.isArray(value)) return `[Array:${value.length}]`;
    if (typeof value === 'object') return `{Object:${Object.keys(value as object).length} keys}`;
    return String(value);
  }

  getLog(): StateMutationRecord[] {
    return [...this.log];
  }

  getMutationCountsByField(): Record<string, number> {
    const counts: Record<string, number> = {};
    for (const record of this.log) {
      counts[record.field] = (counts[record.field] || 0) + 1;
    }
    return counts;
  }

  clear(): void {
    this.log = [];
  }
}

export const stateAudit = new StateAuditLog();

/**
 * Wrap a store's setState to add audit logging.
 * Usage: const auditedStore = wrapWithAudit(originalStore, sessionId);
 */
export function wrapStateForAudit<T extends { setState: (fn: (s: any) => any) => any; getState: () => any }>(
  store: T,
  sessionId: string
): T {
  if (!stateAudit.isEnabled()) return store;

  const originalSetState = store.setState.bind(store);
  const wrappedStore = { ...store };

  wrappedStore.setState = (fn: (s: any) => any) => {
    const oldState = store.getState();
    const caller = new Error().stack?.split('\n')[2]?.trim() || 'unknown';
    const result = originalSetState(fn);
    const newState = store.getState();
    stateAudit.diffAndRecord(oldState, newState, caller, sessionId);
    return result;
  };

  return wrappedStore as T;
}
TEMPLATE

echo "Artifacts:"
echo "  Plan: ${PLAN_FILE}"
echo "  Template: ${TEMPLATE_FILE}"
echo ""
echo "PASSED: State mutation audit analysis complete"
exit 0
