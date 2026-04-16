# Scaffolding Assessment Report: Open-ClaudeCode

**Project:** Open-ClaudeCode (open-source reconstruction of Claude Code CLI v2.1.88)
**Date:** 2026-04-09
**Source Location:** /Users/josh_folder/Open-ClaudeCode
**Assessor:** Autonomous scaffolding analysis (without skill)

---

## 1. Project Profile

| Attribute | Value |
|---|---|
| Language | TypeScript |
| Runtime | Node.js / Bun |
| UI Framework | React + Ink (terminal) |
| Source Files | ~1,888 TypeScript files |
| Entry Point | `src/main.tsx` -> `src/screens/REPL.tsx` -> `src/QueryEngine.ts` |
| Build System | None (recovered from compiled source maps) |
| Test Runner | None |
| CI/CD | None |
| Lint Scripts | 8 Golden Principle linters in `rules/scripts/` |

### Key Architectural Modules

| Module | Path | Files | Role |
|---|---|---|---|
| Tools | `src/tools/` | ~185 | 40+ tool implementations (BashTool, FileEditTool, AgentTool, etc.) |
| Commands | `src/commands/` | ~208 | 60+ slash commands |
| Hooks | `src/hooks/` | ~105 | 100+ React hooks |
| Components | `src/components/` | ~391 | React/Ink UI components |
| Services | `src/services/` | ~131 | External integrations (API, MCP, OAuth, analytics, LSP) |
| Utils | `src/utils/` | ~565 | Utility functions |
| State | `src/state/` | ~6 | AppState + AppStateStore (Zustand-like) |
| Types | `src/types/` | varies | Shared type definitions (dependency inversion layer) |

---

## 2. Existing Controllability Assessment

### What Exists
- **Golden Principle lint scripts** (`rules/scripts/lint-gp001.sh` through `lint-gp008.sh`): Shell-based static analysis checking 8 architectural rules (tool signatures, circular deps, feature flags, state mutation, MCP naming, error wrapping, command types, typed errors).
- **Check runner** (`rules/scripts/check.py`): Python orchestrator that runs all GP linters, supports `--priority`, `--rule`, `--fix`, `--verbose` flags.
- **Rule registry** (`rules/_registry.json`): Machine-readable registry of all rules with priority, verification status, and file references.

### What Is Missing

| Gap | Severity | Description |
|---|---|---|
| No dependency graph analysis | HIGH | No way to detect circular imports beyond barrel-file heuristics. A tool like `madge` or `dependency-cruiser` would give precise cycle detection. |
| No type-checking gate | HIGH | No `tsc --noEmit` gate. TypeScript structural errors silently accumulate across 1,888 files. |
| No import direction enforcement | MEDIUM | No linter enforces the dependency direction rule (utils <- types <- services <- tools). |
| No API surface validation | MEDIUM | No check that tool `call()` signatures match the `buildTool()` factory pattern precisely. |
| No dead code detection | LOW | No way to find unreachable exports across 565 utility files. |
| No schema validation | MEDIUM | No validation that Zod schemas in `src/schemas/` match runtime expectations. |
| No CI integration | CRITICAL | Lint scripts exist but are never run automatically. No GitHub Actions, no pre-commit hooks, no CI pipeline. |
| No test infrastructure | CRITICAL | Zero test files exist. No test runner, no test configuration, no test helpers. |

---

## 3. Existing Observability Assessment

### What Exists
- **Startup profiler** (`src/utils/startupProfiler.ts`): Detailed phase timing with memory snapshots, triggered by `CLAUDE_CODE_PROFILE_STARTUP=1`.
- **Profiler base** (`src/utils/profilerBase.ts`): Shared timeline format for startup, query, and headless profilers.
- **Debug logging** (`src/utils/debug.ts`): Buffered file writer with filterable levels (verbose/debug/info/warn/error), controlled by `CLAUDE_CODE_DEBUG_LOG_LEVEL`.
- **Cost tracker** (`src/cost-tracker.ts`): Tracks token usage, API duration, costs per model, cache stats.
- **Diagnostic tracking** (`src/services/diagnosticTracking.ts`): Tracks file-level diagnostics (errors, warnings) from LSP/MCP.
- **Analytics** (`src/services/analytics/`): Statsig-based event logging (sampled).
- **Internal logging** (`src/services/internalLogging.ts`): K8s/container context logging.

### What Is Missing

| Gap | Severity | Description |
|---|---|---|
| No structured event bus | HIGH | No centralized event emitter for tool lifecycle events (start, progress, error, complete). Observability is scattered across individual modules. |
| No tool execution timing | HIGH | No per-tool latency histogram. Cost tracker has `getTotalToolDuration()` but no per-tool breakdown. |
| No query pipeline tracing | HIGH | QueryEngine orchestrates a complex pipeline (user input -> query -> tool dispatch -> result -> next turn) but has no trace spans or correlation IDs. |
| No state mutation audit log | MEDIUM | AppState changes via `setState()` but no log of what changed, when, or why. Hard to debug state-related UI bugs. |
| No error correlation | MEDIUM | Errors are typed (ClaudeError hierarchy) but not correlated with request IDs or session context. |
| No performance regression baseline | MEDIUM | Startup profiler runs but has no baseline to compare against. No historical data storage. |
| No health check endpoint | LOW | No way to programmatically verify the CLI is functional without running a full session. |
| No metric aggregation | LOW | Individual metrics exist (cost, timing, tokens) but are not aggregated into dashboards or alerts. |

---

## 4. Scaffolding Recommendations

Based on the assessment, the following scaffolding scripts have been generated:

### Controllability Scripts

| Script | Purpose |
|---|---|
| `scaffold-controllability.sh` | Master scaffolding runner - sets up all controllability infrastructure |
| `lint-import-direction.sh` | Validates dependency direction (utils <- types <- services <- tools) |
| `lint-export-counts.sh` | Detects potential dead code by counting exports vs. imports |
| `analyze-deps.sh` | Generates dependency graph and detects circular imports |
| `validate-tool-signatures.sh` | Validates tool `call()` signatures against the buildTool() pattern |
| `run-all-gates.sh` | Runs all controllability gates with summary output |

### Observability Scripts

| Script | Purpose |
|---|---|
| `scaffold-observability.sh` | Master scaffolding runner - sets up all observability infrastructure |
| `instrument-tool-lifecycle.sh` | Adds lifecycle event instrumentation to tool files |
| `trace-query-pipeline.sh` | Adds trace spans to the query pipeline (QueryEngine -> query -> tools) |
| `audit-state-mutations.sh` | Adds state mutation audit logging to AppStateStore |
| `collect-metrics.sh` | Collects and aggregates all available metrics into a report |

### Integration Scripts

| Script | Purpose |
|---|---|
| `scaffold-all.sh` | Runs both controllability and observability scaffolding |
| `verify-scaffolding.sh` | Verifies all scaffolding is correctly installed and operational |
| `ci-pipeline.yml` | GitHub Actions CI pipeline template |

---

## 5. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Scaffolding scripts produce false positives on recovered code | HIGH | MEDIUM | All scripts include `--baseline` mode to capture current state as reference |
| Import direction analysis fails due to dynamic imports | MEDIUM | LOW | Scripts handle dynamic `import()` patterns and `require()` calls |
| Tool signature validation misses custom tool patterns | MEDIUM | MEDIUM | Scripts use configurable pattern lists |
| State mutation audit log degrades performance | LOW | MEDIUM | Audit logging is behind `CLAUDE_STATE_AUDIT=1` env flag |
| CI pipeline cannot run tests (no test infra) | CERTAIN | HIGH | CI focuses on static analysis gates first, test scaffolding is future work |

---

## 6. Implementation Priority

1. **Phase 1 - Static Gates (Immediate):** Import direction linter, export count analyzer, tool signature validator, CI pipeline with existing GP linters
2. **Phase 2 - Dependency Analysis (Week 1):** Full dependency graph, circular import detection, dead code identification
3. **Phase 3 - Runtime Observability (Week 2):** Tool lifecycle instrumentation, query pipeline tracing, state mutation audit
4. **Phase 4 - Test Infrastructure (Future):** Test runner setup, test helpers, initial test suite for critical paths
