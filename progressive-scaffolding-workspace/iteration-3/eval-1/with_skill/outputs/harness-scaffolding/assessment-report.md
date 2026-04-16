# Open-ClaudeCode - Harness Assessment Report

**Project**: Open-ClaudeCode (`/Users/josh_folder/Open-ClaudeCode`)
**Date**: 2026-04-09
**Assessed by**: progressive-scaffolding skill (REFINE LOOP)

---

## Step 1.0: Pre-Check — Is This a Software Project?

**Result**: YES. This is a software project.

Evidence:
- Has `package/package.json` with `bin` field (CLI tool: `@anthropic-ai/claude-code`)
- ~1,888 TypeScript/TSX source files in `src/`
- Pre-compiled CLI bundle (`cli.js` at 12.5MB)
- Custom lint scripts in `rules/scripts/` (8 Golden Principle linters + runner)
- No `tsconfig.json` or build system (read-only recovered source from npm source maps)

---

## Step 1.1: Project Type Detection

**Primary Type**: `cli` (Confidence: 1 — default)

| Type     | Score | Notes |
|----------|-------|-------|
| backend  | 0     | No web framework deps |
| mobile   | 0     | No mobile frameworks |
| **cli**  | 1     | Has `bin` in package.json, CLI tool |
| embedded | 0     | N/A |
| desktop  | 0     | N/A |

**Note**: The `package.json` has a `bin` field pointing to `cli.js`, confirming this is a CLI project. The scripts detection did not score higher because the `package.json` lives in `package/` subdirectory (not root) and has no `scripts.test` entry. However, the project does have `rules/scripts/check.py` which acts as a custom lint/test runner for Golden Principles.

---

## Step 1.2: Probe Results (Initial Assessment)

### Controllability (E1-E4)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **E1 Execute** | Level 1 | No build system (no Makefile, no scripts in root package.json). Only bash available. The `package/package.json` has no test/start/build scripts. However, `rules/scripts/check.py` can execute lint checks via bash subprocess. |
| **E2 Intervene** | Level 2 | Directory is writable. Agent can create/modify files. |
| **E3 Input** | Level 2 | Uses `process.env` extensively (found in history.ts, ink modules, proxy). No `.env` file but environment variables are used for configuration. Has `examples/` with config examples. |
| **E4 Orchestrate** | Level 1 | No Makefile with chained commands. No docker-compose. No npm scripts. Multi-step workflows are manual. However, `rules/scripts/check.py` orchestrates multiple lint scripts. |

**Controllability Score**: 6/12

### Observability (O1-O4)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **O1 Feedback** | Level 2 | Code uses `console.log` extensively. Lint scripts produce structured stdout output with pass/fail per rule. |
| **O2 Persist** | Level 3 | Custom structured logging in source code. The `check.py` runner captures subprocess output. React/Ink terminal UI produces structured output. |
| **O3 Queryable** | Level 1 | No `.harness/observability` directory. No log query tools. Logs are ephemeral (stdout only). No `jq`-parseable log files. |
| **O4 Attribute** | Level 2 | Source code uses correlation-like patterns (request IDs in API calls, trace-like patterns in tool execution pipeline). |

**Observability Score**: 8/12

### Verification (V1-V3)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **V1 Exit Code** | Level 1 | `package.json` has no `"test"` script. No Makefile with test target. However, `rules/scripts/check.py` does return exit code 0/1 and individual lint scripts return proper exit codes (0=pass, 1=fail). |
| **V2 Semantic** | Level 2 | `check.py` produces structured text output with emoji status indicators, rule IDs, and summary counts. Individual lint scripts have structured output (header, violations, result). |
| **V3 Automated** | Level 1 | No CI/CD (no `.github/workflows`). No pre-commit hooks. No automated verification. Lint scripts exist but must be run manually. |

**Verification Score**: 4/9

---

## RE-ASSESS Results (After Scaffolding)

| Dimension | Previous | Current | Change | Evidence of Improvement |
|-----------|----------|---------|--------|------------------------|
| **E1 Execute** | Level 1 | Level 2 | +1 | Root `Makefile` with `lint`, `check`, `verify`, `test-auto` targets. All delegate to `.harness/controllability/Makefile`. |
| **E2 Intervene** | Level 2 | Level 2 | 0 | Already at Level 2. Writable directory. |
| **E3 Input** | Level 2 | Level 2 | 0 | Already at Level 2. `process.env` usage, config examples. |
| **E4 Orchestrate** | Level 1 | Level 2 | +1 | `.harness/controllability/Makefile` has multi-step targets: `test-auto` chains lint + parse + log. `verify` chains structure check + lint. `status` aggregates multiple data sources. |
| **O1 Feedback** | Level 2 | Level 2 | 0 | Already at Level 2. |
| **O2 Persist** | Level 3 | Level 3 | 0 | Already at Level 3. |
| **O3 Queryable** | Level 1 | Level 3 | +2 | `.harness/observability/log.sh` with `recent`, `search`, `follow`, `list`, `summary` commands. Log directory with timestamped files. |
| **O4 Attribute** | Level 2 | Level 3 | +1 | `.harness/observability/trace.sh` injects correlation IDs. `test-auto.sh` includes correlation IDs in JSON output. `start.sh` generates correlation IDs per run. |
| **V1 Exit Code** | Level 1 | Level 2 | +1 | `verify.sh` and `test-auto.sh` return semantic exit codes (0=pass, >0=fail). Root `Makefile` `lint` target propagates exit codes from `check.py`. |
| **V2 Semantic** | Level 2 | Level 3 | +1 | `test-auto.sh` outputs JSON status objects: `{"status":"pass|fail","framework":"gp-lint","correlation_id":"...","timestamp":"...","log_file":"..."}`. `health.sh` outputs full JSON status. `metrics.sh` outputs JSON metrics. |
| **V3 Automated** | Level 1 | Level 2 | +1 | `test-auto.sh` can be invoked by an agent without human intervention. `verify.sh` runs autonomously. Root `Makefile` provides standard entry points (`make verify`, `make test-auto`). |

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
    +-- observability/
        +-- log.sh                              # recent, search, follow, list, summary
        +-- health.sh                           # JSON health status (structure + last lint + CLI status)
        +-- trace.sh                            # Correlation ID wrapper for any command
        +-- metrics.sh                          # JSON project metrics (file counts, lint stats)
        +-- logs/                               # Log output directory
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

- **E1 Execute**: `make lint` or `python3 rules/scripts/check.py`
- **E4 Orchestrate**: `make verify` (structure + lint), `make test-auto` (lint + parse + log)
- **O3 Queryable**: `.harness/observability/log.sh` (recent, search, list, summary)
- **O4 Attribute**: `.harness/observability/trace.sh` (correlation ID injection)
- **V1 Exit Code**: All scripts return 0=pass, non-zero=fail
- **V2 Semantic**: `test-auto.sh` and `health.sh` output JSON
- **V3 Automated**: `make test-auto` runs without human intervention
