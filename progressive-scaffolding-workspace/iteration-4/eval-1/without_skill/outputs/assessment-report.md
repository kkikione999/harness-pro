# Open-ClaudeCode - Harness Assessment Report

**Project**: Open-ClaudeCode (`/Users/josh_folder/Open-ClaudeCode`)
**Assessment Date**: 2026-04-09
**Assessed by**: progressive-scaffolding (no skill, agent-only)

---

## Step 1.0: Pre-Check -- Is This a Software Project?

**Result**: YES. This is a software project.

Evidence:
- `package/package.json` with `bin` field (CLI tool: `@anthropic-ai/claude-code` v2.1.88)
- 1,888 TypeScript/TSX source files in `src/`
- Pre-compiled CLI bundle (`cli.js` at 12.5MB, zero runtime deps)
- Custom lint scripts in `rules/scripts/` (8 Golden Principle linters + `check.py` runner)
- Rich telemetry infrastructure in source (`src/utils/telemetry/`, `src/services/analytics/`)
- No `tsconfig.json` or build system -- source recovered from npm source maps (read-only analysis project)

---

## Step 1.1: Project Type Detection

**Primary Type**: `cli` (Confidence: HIGH)

| Type     | Score | Evidence |
|----------|-------|----------|
| backend  | 0     | No web framework deps, no server entry point |
| mobile   | 0     | No mobile frameworks |
| **cli**  | 1     | Has `bin` field in package.json (`cli.js`), terminal UI via React/Ink |
| embedded | 0     | N/A |
| desktop  | 0     | N/A |

**Note**: The project has a single `package/package.json` with no `scripts.test`, `scripts.build`, or `scripts.lint` entries. The only script is `prepare` which blocks direct npm publishing. The project relies on `rules/scripts/check.py` as its lint/test runner.

---

## Step 1.2: Probe Results (Current State -- No Existing Scaffolding)

### Controllability (E1-E4)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **E1 Execute** | Level 1 | No root Makefile. No build system. No `scripts` in package.json. Only `bash` + `python3` available to run `rules/scripts/check.py` and individual lint scripts. |
| **E2 Intervene** | Level 2 | Directory is writable. Agent can create/modify files. Verified by writing test files. |
| **E3 Input** | Level 2 | Uses `process.env` extensively (found in history.ts, ink modules, proxy config). No `.env` file but environment variables are the configuration mechanism. Has `examples/` with config examples. |
| **E4 Orchestrate** | Level 1 | No Makefile with chained commands. No docker-compose. No npm scripts. `check.py` orchestrates multiple lint scripts but is not connected to a build system. Multi-step workflows must be done manually. |

**Controllability Score**: 6/12

### Observability (O1-O4)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **O1 Feedback** | Level 2 | Extensive `console.log`/`console.error` in source. Lint scripts produce structured stdout with pass/fail per rule (emoji + rule ID + violation details). |
| **O2 Persist** | Level 3 | Rich telemetry infrastructure in source: `src/utils/telemetry/` (9 files including `bigqueryExporter.ts`, `perfettoTracing.ts`, `sessionTracing.ts`). `src/services/analytics/` (9 files including `datadog.ts`, `firstPartyEventLogger.ts`). Structured logging via `src/utils/telemetry/logger.ts`. No log *directory* on disk (output goes to cloud sinks). |
| **O3 Queryable** | Level 1 | No `.harness/observability` directory. No log query tools. No persisted log files on disk. Logs are ephemeral (stdout only) or sent to remote services (BigQuery). No local `jq`-parseable log files. |
| **O4 Attribute** | Level 2 | Source code has correlation-like patterns: `sessionTracing.ts`, `telemetryAttributes.ts`, request IDs in API calls. But no correlation ID injection at the harness level. |

**Observability Score**: 8/12

### Verification (V1-V3)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **V1 Exit Code** | Level 1 | No `"test"` script in package.json. No Makefile with test target. `rules/scripts/check.py` does return exit code 0/1, and individual lint scripts return proper exit codes. But there is no standard entry point (no `make lint`, no `npm test`). |
| **V2 Semantic** | Level 2 | `check.py` produces structured text: emoji status indicators, rule IDs, violation counts, summary. Individual lint scripts have structured output (header, violations, result). Not machine-readable JSON yet. |
| **V3 Automated** | Level 1 | No CI/CD (no `.github/workflows`). No pre-commit hooks. No automated verification. Lint scripts exist but must be run manually via `python3 rules/scripts/check.py`. |

**Verification Score**: 4/9

---

## Current Scores Summary

| Category | Score | Usable? (All dims >= L2?) |
|----------|-------|---------------------------|
| Controllability | 6/12 | NO (E1 and E4 at Level 1) |
| Observability | 8/12 | YES (all O1-O4 >= Level 2) |
| Verification | 4/9 | NO (V1 and V3 at Level 1) |

**Overall: NOT USABLE for autonomous agent work**

6 of 11 dimensions are at Level 1. The project has excellent intrinsic observability (telemetry infrastructure in source code) but lacks the operational scaffolding that lets an agent actually use it.

---

## Priority Gaps (Ranked by Impact)

1. **E1 Execute** (L1 -> L2): No root Makefile or standard build entry point. **Fix**: Add root Makefile delegating to `.harness/controllability/Makefile`, which wraps `check.py` and provides `make lint`, `make verify`, `make test-auto` targets.

2. **E4 Orchestrate** (L1 -> L2): No multi-step orchestration. **Fix**: `.harness/controllability/Makefile` with chained targets: `verify` (structure + lint), `test-auto` (lint + parse + log capture), `status` (aggregate).

3. **V3 Automated** (L1 -> L2): No CI/CD, no automated verification. **Fix**: Add `.harness/ci/ci-pipeline.yml` (GitHub Actions) that runs `make verify` on push/PR.

4. **V1 Exit Code** (L1 -> L2): No standard test entry point with exit code propagation. **Fix**: `make lint` and `make verify` targets that propagate exit codes from `check.py`.

5. **V2 Semantic** (L2 -> L3): Output is structured text, not machine-readable. **Fix**: `test-auto.sh` wraps `check.py` and emits JSON status objects alongside human output.

---

## RE-ASSESS Results (After Scaffolding)

| Dimension | Previous | Current | Change | Evidence of Improvement |
|-----------|----------|---------|--------|------------------------|
| **E1 Execute** | Level 1 | Level 2 | +1 | Root `Makefile` with `lint`, `check`, `verify`, `test-auto`, `status`, `health`, `logs`, `trace` targets. All delegate to `.harness/controllability/Makefile`. |
| **E2 Intervene** | Level 2 | Level 2 | 0 | Already at Level 2. Writable directory. |
| **E3 Input** | Level 2 | Level 2 | 0 | Already at Level 2. `process.env` usage, config examples. |
| **E4 Orchestrate** | Level 1 | Level 2 | +1 | `.harness/controllability/Makefile` has multi-step targets: `test-auto` chains lint + parse + log. `verify` chains structure check + lint. `status` aggregates multiple data sources. |
| **O1 Feedback** | Level 2 | Level 2 | 0 | Already at Level 2. |
| **O2 Persist** | Level 3 | Level 3 | 0 | Already at Level 3. |
| **O3 Queryable** | Level 1 | Level 3 | +2 | `.harness/observability/log.sh` with `recent`, `search`, `follow`, `list`, `summary` commands. Log directory with timestamped files. `metrics.sh` outputs JSON project metrics. |
| **O4 Attribute** | Level 2 | Level 3 | +1 | `.harness/observability/trace.sh` injects correlation IDs. `test-auto.sh` includes correlation IDs in JSON output. `start.sh` generates correlation IDs per run. |
| **V1 Exit Code** | Level 1 | Level 2 | +1 | `verify.sh` and `test-auto.sh` return semantic exit codes (0=pass, >0=fail). Root `Makefile` `lint` target propagates exit codes from `check.py`. |
| **V2 Semantic** | Level 2 | Level 3 | +1 | `test-auto.sh` outputs JSON status objects: `{"status":"pass|fail","framework":"gp-lint","correlation_id":"...","timestamp":"...","log_file":"..."}`. `health.sh` outputs full JSON status. `metrics.sh` outputs JSON metrics. |
| **V3 Automated** | Level 1 | Level 2 | +1 | `test-auto.sh` can be invoked by an agent without human intervention. `verify.sh` runs autonomously. Root `Makefile` provides standard entry points (`make verify`, `make test-auto`). CI pipeline available for `.github/workflows/`. |

---

## Updated Scores

| Category | Previous | Current | Usable? |
|----------|----------|---------|---------|
| Controllability | 6/12 | 8/12 | YES (all E1-E4 >= Level 2) |
| Observability | 8/12 | 11/12 | YES (all O1-O4 >= Level 2) |
| Verification | 4/9 | 7/9 | YES (all V1-V3 >= Level 2) |

**Overall: USABLE for autonomous agent work**

All 11 dimensions are at Level 2 or above.

---

## Generated Scaffolding Inventory

```
Open-ClaudeCode/
+-- Makefile                                    # Root entry point (delegates to .harness)
+-- .harness/
    +-- assessment-report.md                    # This report
    +-- controllability/
    |   +-- Makefile                            # make lint, check, verify, test-auto, status, logs, health, trace, clean
    |   +-- start.sh                            # Launch CLI with logging and correlation ID
    |   +-- stop.sh                             # Stop CLI process
    |   +-- verify.sh                           # Structure + lint verification
    |   +-- test-auto.sh                        # Automated lint + JSON result + log capture
    |   +-- analyze-deps.sh                     # Dependency graph analysis + cycle detection
    |   +-- lint-import-direction.sh            # Enforce module layer hierarchy
    +-- observability/
    |   +-- log.sh                              # recent, search, follow, list, summary
    |   +-- health.sh                           # JSON health status (structure + last lint + CLI status)
    |   +-- trace.sh                            # Correlation ID wrapper for any command
    |   +-- metrics.sh                          # JSON project metrics (file counts, lint stats)
    |   +-- logs/                               # Log output directory (empty, created at runtime)
    +-- ci/
        +-- ci-pipeline.yml                     # GitHub Actions CI (copy to .github/workflows/)
```

---

## Agent Usage Guide

### Quick Commands (from project root)

```bash
# Verify project health
make verify

# Run all Golden Principle linters
make lint

# Run automated test with log capture
make test-auto

# View project status
make status

# Search logs for failures
cd .harness/observability && ./log.sh search "FAIL"

# Get JSON health status
make health

# Trace a command with correlation ID
make trace CMD='python3 rules/scripts/check.py --rule GP-001'
```

### Integration Points

| Dimension | Entry Point | Description |
|-----------|-------------|-------------|
| E1 Execute | `make lint` | Run Golden Principle linters via check.py |
| E4 Orchestrate | `make verify` | Structure check + lint in one command |
| E4 Orchestrate | `make test-auto` | Lint + parse + log capture |
| O3 Queryable | `.harness/observability/log.sh` | Search/recent/follow/list/summary |
| O4 Attribute | `.harness/observability/trace.sh` | Correlation ID injection |
| V1 Exit Code | All scripts | 0=pass, non-zero=fail |
| V2 Semantic | `make test-auto` | JSON status output |
| V3 Automated | `make test-auto` | Runs without human intervention |
