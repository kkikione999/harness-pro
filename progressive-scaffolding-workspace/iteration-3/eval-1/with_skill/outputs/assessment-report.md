# Progressive Scaffolding Assessment Report

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

## Step 1.2: Probe Results

### Controllability (E1-E4)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **E1 Execute** | Level 1 | No build system (no Makefile, no scripts in root package.json). Only bash available. The `package/package.json` has no test/start/build scripts. However, `rules/scripts/check.py` can execute lint checks via bash subprocess. |
| **E2 Intervene** | Level 2 | Directory is writable. Agent can create/modify files. |
| **E3 Input** | Level 2 | Uses `process.env` extensively (found in history.ts, ink modules, proxy). No `.env` file but environment variables are used for configuration. Has `examples/` with config examples. |
| **E4 Orchestrate** | Level 1 | No Makefile with chained commands. No docker-compose. No npm scripts. Multi-step workflows are manual. However, `rules/scripts/check.py` orchestrates multiple lint scripts. |

**Controllability Score**: 6/12 (needs improvement: E1 and E4 below Level 2)

### Observability (O1-O4)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **O1 Feedback** | Level 2 | Code uses `console.log` extensively. Lint scripts produce structured stdout output with pass/fail per rule. |
| **O2 Persist** | Level 3 | Custom structured logging in source code. The `check.py` runner captures subprocess output. React/Ink terminal UI produces structured output. |
| **O3 Queryable** | Level 1 | No `.harness/observability` directory. No log query tools. Logs are ephemeral (stdout only). No `jq`-parseable log files. |
| **O4 Attribute** | Level 2 | Source code uses correlation-like patterns (request IDs in API calls, trace-like patterns in tool execution pipeline). |

**Observability Score**: 8/12 (needs improvement: O3 below Level 2)

### Verification (V1-V3)

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **V1 Exit Code** | Level 1 | `package.json` has no `"test"` script. No Makefile with test target. However, `rules/scripts/check.py` does return exit code 0/1 and individual lint scripts return proper exit codes (0=pass, 1=fail). |
| **V2 Semantic** | Level 2 | `check.py` produces structured text output with emoji status indicators, rule IDs, and summary counts. Individual lint scripts have structured output (header, violations, result). |
| **V3 Automated** | Level 1 | No CI/CD (no `.github/workflows`). No pre-commit hooks. No automated verification. Lint scripts exist but must be run manually. |

**Verification Score**: 4/9 (needs improvement: V1 and V3 below Level 2)

---

## Step 1.3: Gap Analysis

### Critical Gaps (Below Level 2 — "Usable" Threshold)

| Dimension | Current | Target | Gap | Root Cause |
|-----------|---------|--------|-----|------------|
| **E1 Execute** | Level 1 | Level 2 | No build/test system at project root | `package.json` only has `prepare` script. No Makefile. Need to wrap existing lint infrastructure. |
| **E4 Orchestrate** | Level 1 | Level 2 | No multi-step automation | No task runner. Need Makefile/scripts that chain operations. |
| **O3 Queryable** | Level 1 | Level 2 | No log query mechanism | No log directory, no structured log files. Need to capture and store lint/test output. |
| **V1 Exit Code** | Level 1 | Level 2 | No standard test exit codes | `check.py` exists but is not wired into a standard test command. Need to expose it via npm scripts or Makefile. |
| **V3 Automated** | Level 1 | Level 2 | No CI, no hooks | No automation at all. Need at minimum a script-based verification flow. |

### Near-Gaps (Level 2, but fragile)

| Dimension | Current | Risk |
|-----------|---------|------|
| **E3 Input** | Level 2 | Relies on `process.env` usage in source but no `.env` file or config documentation at root |
| **O4 Attribute** | Level 2 | Correlation patterns exist in code but no externalized tracing for agent use |

---

## Recommended Scaffolding

Based on gaps, the following `.harness/` scaffolding is needed:

### Controllability (to fix E1, E4)
1. **Makefile** — Targets: `lint`, `check`, `verify`, `test-auto`, `help`
2. **start.sh** — Launch the CLI for testing
3. **stop.sh** — Stop any running CLI process
4. **verify.sh** — Verify project structure and lint pass
5. **test-auto.sh** — Run `check.py` + parse results

### Observability (to fix O3)
6. **log.sh** — Query captured lint/test logs
7. **health.sh** — JSON health status of project
8. **trace.sh** — Correlation ID wrapper for commands

### Key Design Decisions
- Use `rules/scripts/check.py` as the test runner (already exists, returns proper exit codes)
- Adapt templates for CLI project type (not backend — no HTTP health endpoint)
- No npm test infrastructure (project is read-only recovered source)
- All scripts must work without build step (project has no build system)

---

## Overall Usability Assessment

| Category | Score | Usable? |
|----------|-------|---------|
| Controllability | 6/12 | NO (E1, E4 < Level 2) |
| Observability | 8/12 | NO (O3 < Level 2) |
| Verification | 4/9 | NO (V1, V3 < Level 2) |

**Overall: NOT USABLE for autonomous agent work**

All 5 gap dimensions must be brought to Level 2 before packaging.
