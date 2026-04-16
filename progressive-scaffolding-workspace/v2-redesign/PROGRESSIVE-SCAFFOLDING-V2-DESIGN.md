# Progressive Scaffolding v2 — Complete Redesign

## Executive Summary

**The core reframe**: v1 operates at the **file layer** (check if files exist, if directories are writable). v2 operates at the **code behavior layer** (agent can execute code that reads/writes system state at runtime). The difference is not cosmetic — it is the difference between a dressing gown and a nervous system.

---

## Part I — Root Cause Analysis & v1 vs v2 Comparison

### Why v1 Failed at Its Core Mission

v1's scaffold generates **surface wrappers** — files that wrap existing behavior without changing it. A `log.sh` that calls `echo` does not make your application observable. A `trace.sh` that prints a correlation ID does not make your application traceable. The application code itself must emit structured logs, propagate correlation IDs, expose control knobs. Wrapper scripts are inert without the application cooperating.

The same applies to the evaluation framework. E1 checks "can agent execute bash?" — trivially true for any agent. O3 checks "does `.harness/logging/` exist?" — trivially satisfied by mkdir. The entire evaluation layer is measuring **environmental capability** (what the scaffold provides) rather than **behavioral integration** (what the application actually does when the agent interacts with it).

### v1 vs v2 Comparison Table

| Dimension | v1 | v2 |
|-----------|----|----|
| Target abstraction | File existence | Code runtime behavior |
| Scaffold output | Wrapper scripts, config files | Behavioral code injections + surface wrappers |
| Controllability | "Project is writable" (E2) | Agent can modify runtime config, toggle features, inject state via code |
| Observability | "Logging directory exists" (O3) | Application emits structured logs with semantic schema, agent can query |
| Evaluation | "Does file X exist?" | "Does code behavior Y happen when agent triggers it?" |
| Agent loop | Not defined | Observe→Decide→Act→Verify with concrete checkpoints |
| Skill output | `commands[]` list | Complete agent usage patterns with invocation conditions |
| Progressive strategy | "You can pick which files to generate" | "Inject minimal behavior patches, measured by behavioral delta" |
| Intrusion level | High — generates `.harness/` directory | Zero-new-file by default; behavior changes are patches to existing code |

---

## Part II — New Capability Model: Control Plane vs Surface Wrapper

### The Two-Layer Distinction

**Surface Wrapper** (v1 model):
- A shell script that calls your application's entrypoint
- Passes arguments through unchanged
- Adds a correlation ID to stdout via `tee`
- Checks: file exists, is executable

**Control Plane** (v2 model):
- Code that the agent can **invoke at runtime** to change the application's behavior
- Not a wrapper around the app — **woven into the app itself**
- Agent calls a function, the function mutates app state (config, flags, middleware)
- The app's behavior changes without a restart or redeploy

### Control Plane Capabilities (True Controllability)

A project is truly controllable by an agent if the agent can, via code execution:

1. **Read/write runtime configuration** — not just env vars at startup, but live config mutation
2. **Toggle feature flags** — enable/disable code paths without code changes
3. **Inject state** — modify in-memory state for testing purposes (e.g., mock a database response)
4. **Intercept requests/responses** — add middleware that the agent controls
5. **Trigger internal events** — call internal event emitters that trigger downstream handlers
6. **Query internal state** — read counters, caches, queues without going through public APIs

### Surface Wrapper Capabilities (Passive Support)

These remain useful but are **not sufficient alone**:
- Correlation ID injection (if app doesn't read it, it's noise)
- Log rotation configuration (if app doesn't log, nothing happens)
- Health check endpoints (useful but passive — agent must know to poll)
- Structured log emission (only useful if app code calls the logger)

**Rule**: Every surface wrapper in v2 must be paired with a **behavioral patch** that makes the app actually use it. A log wrapper without a log call is dead code.

---

## Part III — New Evaluation Dimensions

### Redesign Principle

Evaluation must measure **behavioral integration**, not file existence. Each evaluation dimension should answer: "When the agent performs action X, does the application respond with behavior Y?"

### New Controllability Dimensions (C1–C4)

| Dimension | Question | v1 Equivalent | v2 Test |
|-----------|----------|---------------|---------|
| **C1: Config Control** | Can agent modify runtime config via code without restart? | E2 "directory writable" | Inject a config mutation, verify change reflected in next request |
| **C2: Feature Control** | Can agent toggle feature flags via code? | None | Toggle flag, verify different code path executes |
| **C3: State Injection** | Can agent inject test state (mock responses, errors)? | None | Inject mock DB response, verify app uses it |
| **C4: Request Interception** | Can agent add/remove middleware at runtime? | None | Add middleware, verify it fires on next request |

### New Observability Dimensions (O1–O4)

| Dimension | Question | v1 Equivalent | v2 Test |
|-----------|----------|---------------|---------|
| **O1: Semantic Logs** | Does app emit structured logs with defined schema? | O3 "logging dir exists" | Agent triggers action, parses log output, extracts structured fields |
| **O2: Correlation Propagation** | Does correlation ID flow through all components? | O4 "trace.sh exists" | Agent injects correlation ID, verifies it appears in all log entries |
| **O3: Internal State Query** | Can agent query internal state without going through public API? | O2 "storage exists" | Agent calls internal query function, gets structured state |
| **O4: Event Visibility** | Can agent observe internal events? | None | Agent triggers action, verifies event was emitted with correct payload |

### New Value Dimensions (V1–V3)

| Dimension | Question | v1 Problem | v2 Approach |
|-----------|----------|------------|-------------|
| **V1: Intrusion Delta** | How much does scaffold change existing code? | Generates `.harness/` files (additive) | Patches to existing files (modifies), count lines changed |
| **V2: Behavioral Lift** | How much does scaffold enable that didn't exist before? | Trivially 0 (wrappers don't change behavior) | Measure observable behaviors added (count of C/O dimensions that were 0→1) |
| **V3: Agent Loop Completeness** | Can agent complete O→D→A→V cycle without human? | Not defined | Trace a full agent session, count human touchpoints |

### Evaluation Protocol

Each dimension is scored **0/1** (not a level). The scaffold's score is the vector `(C1..C4, O1..O4, V1..V3)`. A perfect score is `(1,1,1,1, 1,1,1,1, 1,1,1)`.

**Behavioral test procedure** (not file inspection):
```
1. Inject scaffold
2. Agent executes: "Trigger feature X and tell me what happened"
3. Capture all outputs (stdout, files written, network calls)
4. Parse outputs for expected behavioral signatures
5. Score 1 if all signatures present, 0 otherwise
```

---

## Part IV — New Scaffold Generation Strategy: Code Injection

### Core Approach: Behavior Patches, Not File Generation

v2 scaffold does not generate new files by default. Instead it injects **behavioral patches** into existing code. The patch:

1. Adds a capability (e.g., structured logging) to an existing file
2. Uses the existing code's idioms (not a foreign DSL)
3. Is minimal — typically 5–20 lines
4. Is conditional — only activates when a specific marker/env var is set (zero intrusion by default)

### The Three Injection Types

#### Type A: Zero-Intrusion Wrapper (Default Off)

```typescript
// INJECTED into src/config/index.ts
// Only activates when HARNESS_CONTROL=1 is set
let _harnessOverrides: Record<string, unknown> = {};
export function setHarnessOverride(key: string, value: unknown) {
  _harnessOverrides[key] = value;
}
export function getHarnessConfig(key: string, fallback: unknown): unknown {
  return process.env.HARNESS_CONTROL === '1' ? _harnessOverrides[key] ?? fallback : fallback;
}
```

Agent usage: `setHarnessOverride('featureX', true)` → app uses overridden config.

#### Type B: Structured Log Injection (Minimal Change)

```typescript
// INJECTED into src/logger.ts (or created if doesn't exist)
// Uses existing logger if present, enhances if not
const HARNESS_SCHEMA = {
  level: 'INFO' as const,
  timestamp: new Date().toISOString(),
  correlationId: process.env.HARNESS_CORRELATION_ID || '',
  component: '',
  message: '',
  metadata: {} as Record<string, unknown>
};

export function harnessLog(event: string, metadata: Record<string, unknown> = {}) {
  const entry = { ...HARNESS_SCHEMA, message: event, metadata, timestamp: new Date().toISOString() };
  console.log(JSON.stringify(entry));
  return entry;
}
```

#### Type C: Feature Flag Injection (Runtime Toggle)

```typescript
// INJECTED into src/featureFlags.ts
const _flags: Record<string, boolean> = {};
export function setFeatureFlag(key: string, value: boolean) {
  _flags[key] = value;
}
export function isFeatureEnabled(key: string): boolean {
  return _flags[key] ?? false;
}
```

### Progressive Injection Levels

Instead of v1's "Level 1/2/3", v2 defines progressive injection tiers based on **behavioral delta**:

| Tier | Injection | Intrusion | Agent Capability Gained |
|------|-----------|-----------|--------------------------|
| **Tier 0 — Surface** | No code changes | None | Wrapper scripts only (passive, like v1) |
| **Tier 1 — Config Control** | Type A injected into config files | <20 lines | Agent can mutate runtime config |
| **Tier 2 — Observability** | Type B injected into logging paths | <30 lines | Agent can parse structured logs |
| **Tier 3 — Feature Control** | Type C injected + existing code patched | <50 lines | Agent can toggle feature flags |
| **Tier 4 — State Injection** | Type A + custom state hooks | <100 lines | Agent can inject/mock internal state |
| **Tier 5 — Full Control Plane** | All above + middleware injection | <200 lines | Agent has complete control + observability |

**Progressive rule**: Start at lowest tier, measure behavioral delta, only proceed to next tier if agent's O→D→A→V loop still has failures.

### Injection Protocol

```
1. SCAN — Read existing code, identify injection points (config reads, log calls, function entry points)
2. PROPOSE — For each injection point, propose the minimal patch
3. APPROVE — User approves/rejects each patch (zero-blind by default)
4. INJECT — Apply approved patches
5. VERIFY — Run behavioral test: agent performs action X, verify behavior Y occurred
6. REPEAT — If verification fails, try alternative injection point
```

---

## Part V — Agent Loop Pattern: O→D→A→V

### The Complete Loop

When an agent receives a task in a v2-scaffolded project, it executes this loop:

```
┌─────────────────────────────────────────────────────────────┐
│  OBSERVE                                                      │
│  1. Agent reads structured logs via:                         │
│     - Parse console output (O1: semantic logs)                │
│     - Query internal state via injected APIs (O3)            │
│     - Check correlation ID propagation (O2)                   │
│     - Listen for internal events (O4)                         │
│  Exit condition: Agent has enough state to form hypothesis   │
├─────────────────────────────────────────────────────────────┤
│  DECIDE                                                       │
│  2. Agent selects intervention:                               │
│     - Modify config via setHarnessOverride() (C1)             │
│     - Toggle feature via setFeatureFlag() (C3)                │
│     - Inject state via state hooks (C2)                       │
│     - Add middleware via injectMiddleware() (C4)               │
│  Exit condition: Agent has a specific, testable plan          │
├─────────────────────────────────────────────────────────────┤
│  ACT                                                          │
│  3. Agent executes via injected control plane:                │
│     - Calls injected functions via Node.js eval or exec        │
│     - Changes take effect immediately (no restart)             │
│  Exit condition: Action completed without error               │
├─────────────────────────────────────────────────────────────┤
│  VERIFY                                                       │
│  4. Agent re-observes to confirm behavioral change:           │
│     - Re-reads logs for new entries                           │
│     - Re-queries state for updated values                      │
│     - Confirms feature flag is reflected in behavior           │
│  Exit condition: Behavioral delta matches expectation         │
│  Loop: If mismatch, return to OBSERVE with updated state      │
└─────────────────────────────────────────────────────────────┘
```

### Loop Checkpoints

| Checkpoint | What Must Exist | Behavioral Test |
|-----------|----------------|-----------------|
| OBSERVE entry | Structured log output | `node app.js` → stdout contains JSON with schema fields |
| DECIDE entry | Config/flag read paths in code | Agent calls `getHarnessConfig('x')` → returns value |
| ACT entry | Setter functions exported | Agent calls `setFeatureFlag('x', true)` → no error |
| VERIFY entry | Re-observable state | Agent re-reads state → updated value reflects ACT |

### Example: Agent Self-Debugging a Bug

**Task**: "The `/api/users` endpoint is returning 500. Find and fix the bug."

```
OBSERVE:
  agent → reads structured logs
  log entry: {"level":"ERROR","message":"DB connection failed","metadata":{"query":"SELECT * FROM users"}}
  → Hypothesis: Database connection is failing

DECIDE:
  agent → calls setHarnessOverride('db_host', 'localhost')  # try localhost
  agent → calls setFeatureFlag('mock_db', true)              # or enable mock
  Plan: Switch to mock DB to bypass the failing connection

ACT:
  agent → eval("setFeatureFlag('mock_db', true)")
  agent → re-requests /api/users

VERIFY:
  agent → reads new log entry
  log entry: {"level":"INFO","message":"Using mock DB","metadata":{"flag":"mock_db"}}
  → Behavioral change confirmed: endpoint now returns 200
  → Agent documents: "Root cause was DB host misconfiguration; temporary fix via mock flag"
```

---

## Part VI — New Skill Format

### Phase 5 Output: Agent Usage Pattern

v2 skill is no longer a list of commands. It is a **structured agent usage pattern** that defines:

1. **When to invoke** — trigger conditions
2. **What capabilities it provides** — the control plane functions
3. **How to use each capability** — with examples
4. **Behavioral contracts** — what the scaffold promises after injection

### Skill Schema

```yaml
skill:
  name: "progressive-scaffolding-v2"
  version: "2.0"
  trigger:
    description: "When agent needs to observe or control a legacy Node.js project"
    conditions:
      - "Project has no existing observability infrastructure"
      - "Agent needs to self-debug without human assistance"
      - "Project is a runtime environment (not a library)"

  capabilities:
    config_control:
      description: "Read/write runtime config without restart"
      functions:
        - name: "setHarnessOverride(key, value)"
          signature: "(key: string, value: unknown) => void"
          example: "setHarnessOverride('api_timeout_ms', 5000)"
          contract: "Next request uses overridden value"
        - name: "getHarnessConfig(key, fallback)"
          signature: "(key: string, fallback: unknown) => unknown"
          example: "getHarnessConfig('api_timeout_ms', 3000)"

    feature_control:
      description: "Toggle feature flags at runtime"
      functions:
        - name: "setFeatureFlag(key, value)"
          signature: "(key: string, value: boolean) => void"
          example: "setFeatureFlag('verbose_logging', true)"
        - name: "isFeatureEnabled(key)"
          signature: "(key: string) => boolean"
          example: "if (isFeatureEnabled('verbose_logging')) { ... }"

    state_injection:
      description: "Inject test state into the application's runtime"
      functions:
        - name: "injectState(path, value)"
          signature: "(path: string, value: unknown) => void"
          example: "injectState('users.current', {id: 1, name: 'Test'})"
          contract: "Application reads injected value as if it were real"
        - name: "queryState(path)"
          signature: "(path: string) => unknown"
          example: "queryState('users.current')"

    observability:
      description: "Parse structured logs and internal events"
      functions:
        - name: "harnessLog(event, metadata)"
          signature: "(event: string, metadata?: Record<string, unknown>) => LogEntry"
          example: "harnessLog('user_created', {userId: 42, provider: 'oauth'})"
          output: "JSON to stdout with schema: {level, timestamp, correlationId, component, message, metadata}"
        - name: "parseStructuredLog(raw)"
          signature: "(raw: string) => LogEntry | null"
          example: "parseStructuredLog(stdout_line)"
          contract: "Returns parsed entry or null if not valid JSON"

  agent_loop:
    observe:
      method: "Parse stdout/stderr for JSON log entries"
      tools: ["bash: node app.js", "grep: parse JSON from output"]
      exit: "Agent identifies anomaly in structured log"
    decide:
      method: "Map anomaly to control plane function"
      options:
        - "Config issue → setHarnessOverride"
        - "Feature path → setFeatureFlag"
        - "Missing data → injectState"
      exit: "Agent selects specific function call"
    act:
      method: "Execute via node -e or inline eval"
      example: "node -e \"require('./src/config').setHarnessOverride('key', 'value')\""
      exit: "Function call succeeds without error"
    verify:
      method: "Re-run application and re-parse logs"
      exit: "Behavioral change confirmed in structured output"

  behavioral_contracts:
    C1: "Calling setHarnessOverride(key, v) → getHarnessConfig(key) returns v within 1 request"
    C2: "Calling setFeatureFlag(key, v) → isFeatureEnabled(key) returns v immediately"
    C3: "Calling injectState(path, v) → queryState(path) returns v immediately"
    O1: "Every harnessLog() call outputs valid JSON with: level, timestamp, correlationId, message, metadata"
    O2: "correlationId field propagates through all nested log calls in same request"
    V1: "All injections are <200 lines total, zero new files by default"

  progressive_tiers:
    tier1:
      name: "Config Control"
      injection: "src/config/index.ts"
      lines: "<20"
      capabilities: ["config_control"]
    tier2:
      name: "Observability"
      injection: "src/logger.ts or src/utils/logger.ts"
      lines: "<30"
      capabilities: ["observability"]
    tier3:
      name: "Feature Control"
      injection: "src/featureFlags.ts (new) + existing code reads"
      lines: "<50"
      capabilities: ["config_control", "feature_control"]
    tier4:
      name: "State Injection"
      injection: "src/state.ts (new)"
      lines: "<100"
      capabilities: ["config_control", "feature_control", "state_injection"]
    tier5:
      name: "Full Control Plane"
      injection: "All above + middleware injection"
      lines: "<200"
      capabilities: ["config_control", "feature_control", "state_injection", "observability"]
```

---

## Part VII — Progressive Strategy for Legacy Projects

### Guiding Principle: Zero Intrusion by Default

The scaffold should change **as little as possible** of the existing project. Every injection must answer: "Does this change the project's behavior when HARNESS_CONTROL is not set?" If yes, it should be rejected.

### Decision Tree for Legacy Projects

```
START: Legacy project with no harness infrastructure
  │
  ├─► Does the project have a config system?
  │     ├─ YES → Inject Type A into existing config file (minimal patch)
  │     └─ NO  → Is there a main entry point?
  │               ├─ YES → Inject Type A near the top of the entry point
  │               └─ NO  → Inject Type A into a new src/config.ts (lowest priority)
  │
  ├─► Does the project have a logger?
  │     ├─ YES → Patch existing logger calls to emit HARNESS_SCHEMA
  │     └─ NO  → Inject Type B as src/logger.ts, document import requirement
  │
  ├─► Does the project read from config at runtime?
  │     ├─ YES → Patch reads to use getHarnessConfig() wrapper
  │     └─ NO  → Tier 1 complete (config control only available via env)
  │
  └─► Can agent modify runtime state without restart?
        ├─ YES → Tier 4/5 achievable
        └─ NO  → Tier 1/2 only (agent must restart process to see changes)
```

### Intrusion Measurement

Track these metrics per injection:

| Metric | How to Measure | Target |
|--------|----------------|--------|
| Lines changed | `git diff --stat` on existing files | <200 lines total |
| New files created | Count of files outside `.harness/` | 0 by default |
| Behavioral change | Does app behave differently without HARNESS_CONTROL=1? | None |
| Breakage risk | Does injection use existing idioms (TypeScript types, existing patterns)? | Must use existing patterns |

### Rollback Strategy

Every injection is wrapped in a comment pattern for easy removal:

```typescript
// [HARNESS-INJECT-START: config_control]
let _harnessOverrides: Record<string, unknown> = {};
// ... injected code ...
// [HARNESS-INJECT-END: config_control]
```

Agent (or scaffold tool) can strip all injections via regex: `/\\/\\/ \\[HARNESS-INJECT-START.*?\\[HARNESS-INJECT-END.*?\\n/g`

---

## Part VIII — Implementation Roadmap

### Phase 1: Core Infrastructure (Weeks 1–2)

1. **Code Analysis Engine**: Read project files, identify injection points
2. **Injection Engine**: Apply Type A/B/C patches to existing files
3. **Behavioral Verifier**: Run agent action, parse output, score dimensions
4. **Rollback Mechanism**: Regex-based injection removal

### Phase 2: Skill Generation (Week 3)

1. **Skill Serializer**: Convert injected capabilities → skill YAML
2. **Example Generator**: Auto-generate usage examples from injection points
3. **Contract Verifier**: Validate behavioral contracts post-injection

### Phase 3: Agent Loop Integration (Week 4)

1. **Loop Executor**: Implement O→D→A→V checkpoint system
2. **State Tracker**: Maintain agent loop state between steps
3. **Human Handoff Detector**: Flag when agent requests human input

### Phase 4: Progressive Tier System (Week 5)

1. **Tier Classifier**: Score project, recommend starting tier
2. **Tier Escalator**: If behavioral test fails, suggest next tier
3. **Intrusion Monitor**: Real-time tracking of injection metrics

---

## Appendix A — v1 vs v2 Summary Table

| Aspect | v1 | v2 |
|--------|----|----|
| Abstraction level | File layer | Code behavior layer |
| Scaffold output | `.harness/` directory with wrapper scripts | Behavioral patches injected into existing files |
| E1 | "Can agent run bash?" (always yes) | "Can agent call injected control functions?" |
| E2 | "Is directory writable?" (always yes) | "Can agent modify runtime config without restart?" |
| O1 | "Can agent read stdout?" (always yes) | "Does stdout contain structured JSON logs?" |
| O2 | "Is storage directory present?" (mkdir) | "Can agent query internal state via API?" |
| O3 | "Does logging dir exist?" (mkdir) | "Does correlation ID propagate through all components?" |
| O4 | "Does trace.sh exist?" (template) | "Can agent observe internal events?" |
| Level model | 1/2/3 (file existence) | C1-C4 × O1-O4 × V1-V3 (behavioral integration) |
| Agent loop | Not defined | O→D→A→V with 4 checkpoints |
| Skill output | `commands: ["echo hello"]` | Full agent usage pattern with trigger, capabilities, contracts |
| Intrusion | Generates new files | Patches existing files, zero intrusion by default |
| Progressive strategy | "Pick which files to generate" | "Inject minimal patches, measure behavioral delta, escalate" |

---

## Appendix B — Key Design Decisions and Rationale

| Decision | Rationale |
|----------|-----------|
| Code injection over file generation | Agent autonomy requires runtime behavior changes, not file presence |
| Zero intrusion by default (HARNESS_CONTROL flag) | Legacy projects cannot have behavioral changes forced upon them |
| Behavioral evaluation over file inspection | File existence proves nothing about agent capability |
| O→D→A→V loop with explicit checkpoints | Agent without structured loop reverts to human-dependent behavior |
| Skill as usage pattern, not command list | Commands are meaningless without invocation context and contracts |
| C1-C4 instead of E1-E4 | Controllability dimensions directly map to agent actions |
| Tier escalation instead of level selection | Projects may need different capabilities at different points |

---

*End of Progressive Scaffolding v2 Design*
