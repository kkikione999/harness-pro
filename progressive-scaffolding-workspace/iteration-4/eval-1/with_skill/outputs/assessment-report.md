# Open-ClaudeCode - Harness Assessment Report

**Project**: Open-ClaudeCode (`/Users/josh_folder/Open-ClaudeCode`)
**Date**: 2026-04-09
**Assessed by**: progressive-scaffolding skill (REFINE LOOP)
**Iteration**: 1

---

## Step 1.0: Pre-Check — Is This a Software Project?

**Result**: YES. This is a software project.

Evidence:
- Has `package/package.json` with `bin` field (CLI tool: `@anthropic-ai/claude-code`)
- ~1,921 TypeScript/TSX source files in `src/`
- Pre-compiled CLI bundle (`package/cli.js`)
- Custom lint scripts in `rules/scripts/` (8 Golden Principle linters + `check.py` runner)
- No `tsconfig.json` at root (read-only recovered source from npm source maps)
- 176 code files vs 74 markdown files (code-dominant)

---

## Step 1.1: Project Type Detection

**Primary Type**: `cli` (Confidence: 1 — default, but confirmed by evidence)

| Type     | Score | Notes |
|----------|-------|-------|
| backend  | 0     | No web framework deps |
| mobile   | 0     | No mobile frameworks |
| **cli**  | 1     | Has `bin` in `package/package.json`, CLI tool `@anthropic-ai/claude-code` |
| embedded | 0     | N/A |
| desktop  | 0     | N/A |

**Justification**: `package/package.json` declares `"bin": {"claude": "cli.js"}` confirming this is a CLI project. The `rules/scripts/check.py` runner orchestrates 8 Golden Principle lint scripts.

---

## Step 1.2: Probe Results (Initial Assessment)

### Controllability (E1-E4)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **E1 Execute** | Level 1 | No root `Makefile`, no npm scripts with test/build/run. `package/package.json` has no `scripts.test`. `rules/scripts/check.py` exists but must be invoked manually via `python3 rules/scripts/check.py`. |
| **E2 Intervene** | Level 2 | Directory is writable. Agent can create/modify files. No Docker for rebuild. |
| **E3 Input** | Level 2 | Extensive `process.env` usage across codebase (history.ts, upstreamproxy, ink modules, tools). No `.env` file but env vars are used for configuration. |
| **E4 Orchestrate** | Level 1 | No Makefile with chained commands. No docker-compose. No npm scripts. `check.py` orchestrates multiple lint scripts but is Python-based, not a standard build orchestration tool. |

**Controllability Score**: 6/12

### Observability (O1-O4)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **O1 Feedback** | Level 3 | 30+ files with console.log/error/warn. `check.py` produces structured stdout with pass/fail per rule. Project has full telemetry infrastructure. |
| **O2 Persist** | Level 3 | Structured telemetry in `src/utils/telemetry/` (9 files: logger, instrumentation, sessionTracing, bigqueryExporter, perfettoTracing). `src/services/analytics/` (9 files: datadog, firstPartyEventLogger, sink). |
| **O3 Queryable** | Level 3 | BigQuery exporter enables SQL queries. Datadog integration. Session tracing with perfetto format. The telemetry infrastructure supports log aggregation (LogQL-style). |
| **O4 Attribute** | Level 3 | Correlation IDs in session tracking (`sessionHistory.ts`, `history.ts`). Request IDs in API calls. Trace/span patterns in tool execution. OpenTelemetry-style instrumentation in `instrumentation.ts`. |

**Observability Score**: 12/12

**Note**: The automated observability probe correctly detected the project's built-in telemetry:
- `src/utils/telemetry/` (9 files): logger.ts, instrumentation.ts, sessionTracing.ts, bigqueryExporter.ts, perfettoTracing.ts, events.ts, etc.
- `src/services/analytics/` (9 files): datadog.ts, firstPartyEventLogger.ts, sink.ts, config.ts, etc.
- Additional: telemetryAttributes.ts, profilerBase.ts, metricsOptOut.ts

### Verification (V1-V3)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **V1 Exit Code** | Level 1 | No `"test"` script in `package.json`. No Makefile with test target. `check.py` does return exit codes (0/1) and individual lint scripts return proper exit codes, but no standard entry point exists at project root. |
| **V2 Semantic** | Level 2 | `check.py` produces structured text with emoji status, rule IDs, summary counts. Individual lint scripts have structured output (header, violations, result). JSON output via `check.py --verbose`. |
| **V3 Automated** | Level 1 | No CI/CD (no `.github/workflows/`). No pre-commit hooks. No automated verification triggers. Lint scripts exist but must be run manually. |

**Verification Score**: 4/9

---

## Summary Scores

| Category | Score | Usable? (All >= Level 2) |
|----------|-------|--------------------------|
| Controllability | 6/12 | NO (E1=1, E4=1) |
| Observability | 12/12 | YES |
| Verification | 4/9 | NO (V1=1, V3=1) |

**Overall: NOT USABLE for autonomous agent work**

### Gaps Preventing Usability

1. **E1 Execute (Level 1)**: No standard build system entry point. Need Makefile or npm scripts wrapping `check.py` and project operations.
2. **E4 Orchestrate (Level 1)**: No multi-step command orchestration. Need Makefile targets that chain operations (verify, test-auto).
3. **V1 Exit Code (Level 1)**: No standard test command that returns exit codes. Need a wrapper that exposes `check.py` exit codes via a standard interface.
4. **V3 Automated (Level 1)**: No CI pipeline. Need `.github/workflows/ci.yml` with lint, verify, and health jobs.

### Priority Gaps (Ranked by Impact)

1. **E1 Execute** — Without a build system entry, agents cannot trigger any operation programmatically.
2. **V1 Exit Code** — Without typed exit codes from a standard test command, agents cannot verify success.
3. **V3 Automated** — Without CI, agents have no automated verification on changes.
4. **E4 Orchestration** — Without chained commands, agents must manually run multi-step flows.
