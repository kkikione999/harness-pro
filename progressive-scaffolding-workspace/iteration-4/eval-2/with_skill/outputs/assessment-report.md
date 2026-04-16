# Open-ClaudeCode - Scaffolding Assessment Report (ASSESS-ONLY)

**Project**: Open-ClaudeCode (`/Users/josh_folder/Open-ClaudeCode`)
**Date**: 2026-04-09
**Mode**: ASSESS-ONLY (gap analysis, no generation)
**Assessed by**: progressive-scaffolding skill

---

## Step 1.0: Pre-Check -- Is This a Software Project?

**Result**: YES. This is a software project (TypeScript CLI).

Evidence:
- `package/package.json` with `bin` field (`@anthropic-ai/claude-code`, v2.1.88)
- ~1,888 TypeScript/TSX source files in `src/`
- Pre-compiled CLI bundle (`cli.js` at 12.5MB)
- Custom lint scripts in `rules/scripts/` (8 Golden Principle linters + runner)
- **No `tsconfig.json` or build system** -- read-only recovered source from npm source maps
- AGENTS.md explicitly states: "This is a READ-ONLY project"

---

## Step 1.1: Project Type Detection

**Primary Type**: `cli` (Confidence: 1 -- default fallback)

| Type     | Score | Notes |
|----------|-------|-------|
| backend  | 0     | No web framework deps |
| mobile   | 0     | No mobile frameworks |
| **cli**  | 1     | Has `bin` in package.json (CLI tool) |
| embedded | 0     | N/A |
| desktop  | 0     | N/A |

**Note**: The `detect-project-type.sh` scored all types as 0 because the `package.json` lives in `package/` subdirectory (not root) and has no `scripts.test` entry. The CLI detection scored 0 because the script checks for `"bin"` in a root `package.json`, not `package/package.json`. The default fallback to `cli` is correct -- this is a CLI tool (`claude` command).

---

## Step 1.2: Probe Results (Current State)

### Controllability (E1-E4)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **E1 Execute** | Level 2 | `rules/scripts/check.py` acts as a build-system-like entry point. It runs 8 Golden Principle linters via bash subprocess. However, there is no root `Makefile` (it was removed), no `npm scripts`, no standard build system. The `check.py` runner is the only executable entry point. |
| **E2 Intervene** | Level 2 | Directory is writable. Agent can create/modify files. No Docker for environment rebuild. |
| **E3 Input** | Level 2 | Code uses `process.env` extensively (CLAUDE_CODE_SKIP_PROMPT_HISTORY, ANTHROPIC_BASE_URL, CLAUDE_CODE_REMOTE, etc.). No `.env` file but has `examples/settings/` and `examples/hooks/` with config examples. |
| **E4 Orchestrate** | Level 1 | No root Makefile with chained commands. No docker-compose. `package.json` has only a `prepare` script. `rules/scripts/check.py` orchestrates multiple lint scripts, but there is no top-level orchestrator like a Makefile. Multi-step workflows are entirely manual. |

**Controllability Score**: 7/12

### Observability (O1-O4)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **O1 Feedback** | Level 3 | Code uses `console.log` extensively. Telemetry infrastructure detected: `src/utils/telemetry/` (9 files), `src/services/analytics/` (9 files), `src/utils/profilerBase.ts`, `src/utils/telemetryAttributes.ts`, `src/utils/telemetry/instrumentation.ts`. JSON structured output present. |
| **O2 Persist** | Level 3 | Structured logging framework detected in source. Telemetry persistence with exporters/tracing. `check.py` captures subprocess output. |
| **O3 Queryable** | Level 3 | Source code references to log aggregation systems (LogQL, BigQuery query patterns). The telemetry infrastructure includes exporters that write to queryable backends. |
| **O4 Attribute** | Level 3 | Source code uses correlation/trace IDs, distributed tracing patterns (OpenTelemetry references, session IDs, parent_session patterns). |

**Observability Score**: 12/12

**Note**: Observability scores are high because the project's **source code** contains extensive telemetry infrastructure. However, these are embedded in the compiled CLI binary, not exposed as harness scripts. An agent cannot directly invoke `src/utils/telemetry/` scripts -- they run inside the CLI. The high scores reflect the product's internal observability, not agent-controllable observability.

### Verification (V1-V3)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **V1 Exit Code** | Level 2 | `check.py` and individual lint scripts return exit codes (0=pass, 1=fail). No standard `npm test` or `Makefile test` target. |
| **V2 Semantic** | Level 2 | `check.py` produces structured text output with rule IDs, violation counts, and summary. Individual lint scripts have structured output (header, violations, result). |
| **V3 Automated** | Level 2 | `check.py` can be invoked without human intervention. No CI/CD (no `.github/workflows`). No pre-commit hooks. No automated triggering on changes. |

**Verification Score**: 6/9

---

## Summary Scores

| Category         | Score  | All >= Level 2? |
|------------------|--------|-----------------|
| Controllability  | 7/12   | NO (E4 at Level 1) |
| Observability    | 12/12  | YES (all at Level 3) |
| Verification     | 6/9    | YES (all at Level 2) |

**Overall: NOT FULLY USABLE for autonomous agent operation**

E4 (Orchestration) is the only dimension below Level 2, but there are significant qualitative gaps even in dimensions that technically pass.

---

## Priority Gaps (Ranked by Impact)

### Gap 1 (CRITICAL): No Top-Level Orchestration (E4: Level 1)

**Impact**: An autonomous agent has no single entry point to execute multi-step workflows. Every operation must be manually chained.

**What's missing**:
- Root `Makefile` with standard targets (`lint`, `verify`, `test-auto`, `status`, `clean`)
- No `.harness/controllability/` directory with orchestration scripts
- `check.py` orchestrates lint scripts internally, but there is no external orchestrator that chains lint + verify + log + report
- No `start.sh` / `stop.sh` / `verify.sh` / `test-auto.sh`

**What exists**:
- `rules/scripts/check.py` can run all 8 linters and report results
- Each `lint-gp*.sh` script is independently executable with exit codes

**What an agent needs**: A Makefile or shell script that provides `make verify`, `make lint`, `make test-auto` so the agent can run verification in one command.

---

### Gap 2 (HIGH): No Agent-Controllable Observability Layer

**Impact**: The project's observability (O1-O4) is entirely embedded in the compiled CLI binary. An external agent cannot query logs, health, metrics, or traces through harness scripts.

**What's missing**:
- `.harness/observability/` directory with `log.sh`, `health.sh`, `metrics.sh`, `trace.sh`
- No log directory for persisted test/lint results
- No JSON health check endpoint
- No correlation ID injection mechanism for agent operations

**What exists**:
- Source code has rich telemetry (`src/utils/telemetry/`, `src/services/analytics/`)
- This telemetry runs inside the CLI, not accessible to an external harness

**What an agent needs**: Harness scripts that wrap `check.py` output with structured logging, log persistence, and queryable log files so the agent can search past results.

---

### Gap 3 (HIGH): No Automated Verification Pipeline (V3: Level 2, but fragile)

**Impact**: Verification requires manual invocation. No CI/CD, no pre-commit hooks, no automated triggering.

**What's missing**:
- `.github/workflows/ci.yml` -- no CI pipeline at all
- No `.harness/ci/` directory with CI configuration
- No pre-commit hooks to auto-run linters
- No file-watcher or git-hook automation

**What exists**:
- `check.py` can run all linters from command line
- Proper exit codes (0/1) enable CI integration

**What an agent needs**: A CI pipeline template (even if not connected to GitHub) and pre-commit hook setup so verification happens automatically.

---

### Gap 4 (MEDIUM): No Build/Test Infrastructure

**Impact**: This is a read-only project (recovered from npm source maps). There is no `tsconfig.json`, no test runner, no compilation step.

**What's missing**:
- No `tsconfig.json` -- cannot compile TypeScript
- No test framework (no jest, vitest, mocha config)
- No test files (`*.test.ts`, `*.spec.ts`)
- No build step (the `cli.js` is pre-compiled)
- No `package.json` scripts for build/test

**What exists**:
- `rules/scripts/check.py` runs structural/pattern linters (not unit tests)
- Pre-compiled `package/cli.js` is the runnable artifact

**Note**: This gap is inherent to the project's nature (recovered source maps). It cannot be fully resolved -- the project is explicitly read-only. The lint scripts serve as the closest approximation to verification.

---

### Gap 5 (LOW): No Dependency Management Layer

**Impact**: An agent cannot check dependency health, detect cycles, or analyze import direction.

**What's missing**:
- No `lint-import-direction.sh` to enforce module layer hierarchy
- No `analyze-deps.sh` for dependency graph and cycle detection
- No `package-lock.json` or `node_modules/` (dependencies are bundled in `cli.js`)

**What exists**:
- GP-002 linter checks for circular dependency patterns
- AGENTS.md documents the types-layer circular dep resolution pattern

---

## Dimension-Level Detail

| Dimension | Level | Status | Key Gap |
|-----------|-------|--------|---------|
| E1 Execute | 2 | PASS | `check.py` provides execution entry point |
| E2 Intervene | 2 | PASS | Writable filesystem |
| E3 Input | 2 | PASS | `process.env` usage, config examples |
| **E4 Orchestrate** | **1** | **FAIL** | No top-level orchestrator (Makefile, etc.) |
| O1 Feedback | 3 | PASS | Rich telemetry in source |
| O2 Persist | 3 | PASS | Structured logging in source |
| O3 Queryable | 3 | PASS | Log aggregation in source |
| O4 Attribute | 3 | PASS | Distributed tracing in source |
| V1 Exit Code | 2 | PASS | Lint scripts return exit codes |
| V2 Semantic | 2 | PASS | Structured text output from check.py |
| V3 Automated | 2 | PASS | check.py runs without human |

**Dimensions at Level 2 or above**: 10/11
**Dimensions below Level 2**: 1/11 (E4)

---

## Qualitative Assessment

### What Works Well for Autonomous Agent Operation
1. **8 mechanical lint rules** with a runner (`check.py`) that provides structured output and exit codes
2. **Rich AGENTS.md** documenting project structure, rules, and how to work with the codebase
3. **Telemetry infrastructure** in source code (though not agent-controllable)
4. **Environment variable configuration** for runtime behavior modification
5. **Progressive rules system** (`rules/`) with registry and mechanical verification

### What Blocks Autonomous Operation
1. **No single-command verification** -- agent must know to run `python3 rules/scripts/check.py` instead of a standard `make verify`
2. **No log persistence** -- lint results vanish after stdout; agent cannot query past results
3. **No orchestration** -- agent cannot chain lint + verify + log + report in one command
4. **No CI feedback loop** -- no automated triggering means agent must remember to run checks
5. **Read-only project nature** -- no unit tests, no build step, no compile-time verification

---

## What Would Be Needed to Reach "Usable" (All Dimensions >= Level 2)

1. **Root Makefile** delegating to `.harness/controllability/Makefile` with targets: `lint`, `verify`, `test-auto`, `status`, `clean`
2. **`.harness/controllability/` scripts**: `start.sh`, `stop.sh`, `verify.sh`, `test-auto.sh`
3. **`.harness/observability/` scripts**: `log.sh`, `health.sh`, `metrics.sh`, `trace.sh`
4. **`.harness/observability/logs/` directory** for persisted test results
5. **`.harness/ci/ci-pipeline.yml`** template for GitHub Actions CI
6. **Pre-commit hook** to auto-run `check.py` on commit

These would raise E4 from Level 1 to Level 2, add agent-controllable observability, and strengthen V3 automation.

---

## Previous Scaffolding State

An earlier iteration generated a complete `.harness/` directory with all the above scaffolding. That scaffolding has been removed (the `.harness/` directory and root `Makefile` no longer exist). The previous assessment report is documented in the skill's history but the actual files are gone. The project is currently in its raw, unscaffolded state.
