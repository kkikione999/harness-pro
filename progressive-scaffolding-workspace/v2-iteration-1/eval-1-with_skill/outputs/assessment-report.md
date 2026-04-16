# Progressive Scaffolding v2 — Assessment Report
# Project: Open-ClaudeCode (Anthropic Claude Code CLI)
# Assessor: progressive-scaffolding skill v2
# Date: 2026-04-09

---

## 1. Project Classification

- **Project Type**: TypeScript/Bun CLI application
- **Source**: 1,888 TypeScript files recovered from source maps
- **Entry Point**: `package/cli.js` (Bun-built)
- **Framework**: Custom terminal UI (Ink/React for terminal rendering)
- **Build System**: Makefile + Bun
- **Language**: TypeScript (Node.js compatible)
- **Assessment**: NOT a content repository — proceed with scaffolding.

---

## 2. Behavioral Capability Gap Matrix (v2 Framework)

### Controllability (C1-C4)

| Dimension | Score | Evidence |
|-----------|-------|----------|
| C1 Config Control | 0/1 | No runtime config mutation system. Existing config reads are static (process.env reads memoized). No `setHarnessOverride()` or `getHarnessConfig()` functions exist. Agent cannot modify config at runtime without restart. |
| C2 Feature Control | 0/1 | No feature flag infrastructure. App uses `feature('FLAG_NAME')` from `bun:bundle` but this is a compile-time flag, not a runtime toggle. No `setFeatureFlag()` or `isFeatureEnabled()` functions. |
| C3 State Injection | 0/1 | No state injection hooks. Error queue in `src/utils/log.ts` is a sink pattern but has no injection mechanism. No `injectState()` or `queryState()` functions. |
| C4 Middleware | 0/1 | No middleware pipeline. The app is a CLI REPL, not a server with a request/response cycle. MCP server config exists but no injection mechanism for middleware. |

### Observability (O1-O4)

| Dimension | Score | Evidence |
|-----------|-------|----------|
| O1 Semantic Logs | 0/1 | Debug logs in `src/utils/debug.ts` emit plain text to files: `"2026-04-09T12:00:00.000Z [DEBUG] message"`. NOT JSON. No structured schema with level/timestamp/message/metadata fields in machine-readable form. |
| O2 Correlation | 0/1 | No correlation ID propagation. `start.sh` generates a `CORRELATION_ID` shell variable but it is NOT passed into the application. The app has no concept of a correlation ID in its structured output. |
| O3 Internal Query | 0/1 | No internal state query API. `src/utils/log.ts` has `getInMemoryErrors()` but this is only for bug reports. No `queryState()` function accessible to agents. |
| O4 Event Visibility | 0/1 | No event system. OpenTelemetry instrumentation exists (`src/utils/telemetry/`) but events are internal to the telemetry system, not exposed as queryable harness events. |

### Value (V1-V3)

| Dimension | Score | Evidence |
|-----------|-------|----------|
| V1 Intrusion Delta | 0/1 | No source code changes yet. All existing `.harness/` files are shell wrappers (v1 surface layer). Total planned intrusion: ~65 lines across 2 files (< 200, zero new files). |
| V2 Behavioral Lift | 0/1 | All 8 C/O dimensions are 0. Injecting Tier 1 + Tier 2 will flip at least C1, O1, O2, O3 to 1. |
| V3 Loop Completeness | 0/1 | Loop not yet tested. Behavioral verification step not performed. |

---

## 3. Vector Score

```
(C1, C2, C3, C4, O1, O2, O3, O4, V1, V2, V3) = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
```

**Score: 0/11 — Zero behavioral capability in the v2 sense.**

The existing v1 scaffolding (shell scripts) provides a surface wrapper but does NOT give agents runtime control or structured observability. The agent must still restart the process, infer structure from raw text, and has no mechanism to mutate runtime behavior.

---

## 4. Existing Infrastructure Analysis

### What's Already There (v1 Surface Layer)

The `.harness/` directory contains:
- `.harness/controllability/` — Makefile + shell scripts (start.sh, stop.sh, verify.sh, test-auto.sh)
- `.harness/observability/` — Shell scripts (log.sh, health.sh, trace.sh)
- `.harness/ci/ci-pipeline.yml` — GitHub Actions CI template
- `.harness/test-result.json` — 4-point smoke test results

These are **passive wrappers**:
- They call `node package/cli.js` and parse exit codes
- They write logs to `.harness/observability/logs/` via `tee`
- They generate correlation IDs in shell but do NOT propagate them into the app
- They check file existence, not behavioral capability

### Key Source Files (v2 Injection Targets)

**1. `src/utils/config.ts` (1,817 lines)**
- Central configuration module
- Reads from `process.env`, `~/.claude.json`, project-level config
- Functions: `getGlobalConfig()`, `getCurrentProjectConfig()`, `isAutoUpdaterDisabled()`, `shouldSkipPluginAutoupdate()`
- Best injection point: Append harness config functions at end, patch env var reads

**2. `src/utils/debug.ts` (~350 lines)**
- Debug logging infrastructure
- `logForDebugging()` emits timestamped text: `"2026-04-09T12:00:00.000Z [DEBUG] message"`
- Writes to `~/.claude/debug/{sessionId}.txt`
- Best injection point: Add harness structured logging, patch `logForDebugging()` to emit JSON when `HARNESS_CONTROL=1`

**3. `src/utils/log.ts` (362 lines)**
- Error logging with sink architecture
- `logError()`, `logMCPError()`, `logMCPDebug()` with in-memory queue
- Error sink initialized at startup
- Existing pattern is extensible — could serve as event system

---

## 5. Tier Recommendation

### Recommended Starting Point: Tier 1 (Config Control) + Tier 2 (Observability)

**Rationale:**
- C1 (Config Control) is the highest-value gap — agents need runtime config mutation to self-debug without restarts
- O1 (Semantic Logs) is the second highest — structured JSON logs are required for the O→D→A→V loop (parse logs → decide → act → verify)
- Both tiers have clear injection points in existing source files
- Combined intrusion: ~65 lines across 2 files — well within budget
- These tiers enable the core O→D→A→V loop: observe structured logs → decide override → act with `setHarnessOverride()` → verify in re-parsed logs

**Tier Escalation Path:**
- Tier 1+2 pass → Tier 3 (Feature Flags) if agents need runtime feature toggles
- Tier 3 pass → Tier 4 (State Injection) if agents need to mock API responses
- Tier 4 pass → Tier 5 (Full Control Plane) if complete autonomy is needed

**Not recommending Tier 0**: The existing v1 scaffolding exists but is insufficient — it doesn't give agents behavioral control. Starting at Tier 1 is appropriate given the project's complexity.

---

## 6. Injection Points Identified

### Tier 1 — Config Control

| File | Line Range | Injection Type | Lines |
|------|-----------|----------------|-------|
| `src/utils/config.ts` | After line 1817 (EOF) | Add new functions | ~13 |
| `src/utils/config.ts` | Lines 1713, 1739 | Patch existing reads | ~8 |
| **Total** | | | **~21 lines** |

**Existing env var reads to patch:**
- Line 1713: `!isEnvTruthy(process.env.FORCE_AUTOUPDATE_PLUGINS)` in `shouldSkipPluginAutoupdate()`
- Line 1739: `isEnvTruthy(process.env.DISABLE_AUTOUPDATER)` in `getAutoUpdaterDisabledReason()`

### Tier 2 — Observability

| File | Line Range | Injection Type | Lines |
|------|-----------|----------------|-------|
| `src/utils/debug.ts` | After line 226 (end of imports + type exports) | Add new functions | ~35 |
| `src/utils/debug.ts` | Lines 203-228 (`logForDebugging()`) | Patch to emit JSON when HARNESS_CONTROL=1 | ~4 |
| **Total** | | | **~39 lines** |

---

## 7. Assessment Summary

```
Assessment: Open-ClaudeCode
Tier Recommendation: Tier 1 (Config Control) + Tier 2 (Observability)

Behavioral Gap Matrix:
  C1 Config Control:       0/1  — No runtime config mutation system
  C2 Feature Control:      0/1  — No feature flag infrastructure (compile-time only)
  C3 State Injection:      0/1  — No state hooks
  C4 Middleware:           0/1  — No middleware pipeline (CLI app)
  O1 Semantic Logs:        0/1  — Plain text debug logs, not JSON
  O2 Correlation:          0/1  — No correlation ID propagation in app
  O3 Internal Query:       0/1  — No internal state query API
  O4 Event Visibility:     0/1  — No event system
  V1 Intrusion Delta:      0/1  — No source changes yet (planned: ~65 lines)
  V2 Behavioral Lift:      0/1  — All 8 C/O gaps open (target: 4+ closed)
  V3 Loop Completeness:    0/1  — Loop not tested

Recommended starting tier: Tier 1 + Tier 2 combined (~65 lines, 2 files)
```
