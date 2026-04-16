# Open-ClaudeCode: Scaffolding Gap Analysis for Autonomous Agent Operation

**Project**: `/Users/josh_folder/Open-ClaudeCode`
**Type**: TypeScript CLI (open-source reconstruction of Claude Code v2.1.88)
**Source**: 1,888 TypeScript/TSX files, ~432k lines, recovered from npm source maps
**Date**: 2026-04-09

---

## Executive Summary

Open-ClaudeCode has a **partial scaffolding foundation** consisting of Golden Principle rules and custom lint scripts, but **no controllability or observability harness is currently present on disk**. A previous scaffolding iteration generated `.harness/` infrastructure (controllability scripts, observability tools, root Makefile), but those artifacts were never committed to git and have been removed from the filesystem. The project remains a **read-only research codebase** with no build system, no test infrastructure, and no CI/CD pipeline.

**Bottom line**: The project cannot currently support autonomous agent operation. It lacks the feedback loops, execution entrypoints, and persistent observability that an agent needs to verify its own work.

---

## 1. What EXISTS (Current State)

### 1.1 Golden Principle Rules System (PRESENT)

| Component | Path | Status |
|-----------|------|--------|
| Rule registry | `rules/_registry.json` | Present, defines 8 rules (GP-001 through GP-008) |
| Rule definitions | `rules/common/golden-principles/GP-00[1-8]-*.md` | 8 markdown files with metadata, rationale, counter-examples |
| Lint runner | `rules/scripts/check.py` | Python3 orchestrator, runs bash lint scripts, produces pass/fail |
| Lint scripts | `rules/scripts/lint-gp00[1-8].sh` | 8 bash scripts with regex-based violation detection |
| TypeScript rules dir | `rules/typescript/` | Empty (no language-specific overrides) |

**Lint results (current run)**:
- 6 of 8 rules PASS
- GP-003 FAILS: 6 violations (hardcoded `process.platform` / `process.env` instead of `feature()`)
- GP-008 FAILS: 28 violations (raw `throw new Error()` instead of typed error classes)

### 1.2 Agent Documentation (PRESENT)

| Component | Path | Status |
|-----------|------|--------|
| Agent guide | `AGENTS.md` | Comprehensive -- project description, directory map, golden principles, working patterns |
| Architecture docs | `docs/reference/architecture.md` | Query pipeline, permission flow, state management |
| Plugin docs | `docs/reference/plugins.md` | Plugin manifest, command/agent schemas |
| Tool creation guide | `docs/guides/creating-a-tool.md` | buildTool() pattern with correct signatures |
| Other docs | `docs/reference/` (5 more), `docs/guides/` (2 more) | Error handling, MCP, settings, commands, UI |

### 1.3 Project Structure (PRESENT)

- `src/` -- 1,888 TypeScript source files across 55+ subdirectories
- `package/` -- Pre-compiled CLI bundle (`cli.js` 12.5MB, zero runtime deps)
- `plugins/` -- 13 official plugins
- `examples/` -- Config examples for hooks and settings

---

## 2. What is MISSING (Gap Analysis)

### 2.1 CONTROLLABILITY GAPS

#### E1: Execute -- How an agent runs things

| Gap | Severity | Description |
|-----|----------|-------------|
| **No root Makefile** | CRITICAL | The root `Makefile` referenced in previous scaffolding does not exist. An agent has no standard entrypoint to discover available operations. |
| **No `make lint` target** | CRITICAL | The `check.py` lint runner works, but there is no Make target to invoke it. Agents need `make lint` as a discoverable command. |
| **No `make verify` target** | CRITICAL | No combined structure + lint verification target exists. |
| **No `make test-auto` target** | HIGH | No automated test execution with log capture and JSON result output. |
| **No `.harness/controllability/` directory** | CRITICAL | The entire controllability layer was ephemeral and is now gone. |
| **No build system** | MEDIUM | No `tsconfig.json`, no `package.json` at root with build scripts. The `package/package.json` only has a publish guard script. This is inherent to the project being recovered source maps. |

#### E2: Intervene -- How an agent modifies the project

| Gap | Severity | Description |
|-----|----------|-------------|
| **No writable scaffolding** | HIGH | `.harness/` directory does not exist. Agent cannot write logs, metrics, or state. |
| **No process management** | HIGH | No `start.sh` / `stop.sh` for CLI lifecycle control. |

#### E3: Input -- How an agent feeds data in

| Gap | Severity | Description |
|-----|----------|-------------|
| **No `.env` configuration** | LOW | Uses `process.env` extensively but has no `.env.example` or documented env vars. The `examples/settings/` directory exists but is sparse. |
| **No stdin/stdout protocol** | MEDIUM | No structured input format for automated agent commands. |

#### E4: Orchestrate -- How an agent chains operations

| Gap | Severity | Description |
|-----|----------|-------------|
| **No chained targets** | CRITICAL | No Makefile with multi-step workflows (e.g., `verify` = structure-check + lint). |
| **No dependency graph** | HIGH | No way to express "run lint only after structure check passes." |

### 2.2 OBSERVABILITY GAPS

#### O1: Feedback -- How an agent sees what happened

| Gap | Severity | Description |
|-----|----------|-------------|
| **No structured output from lint** | MEDIUM | `check.py` uses emoji icons and plain text. JSON output is not available as an option. An agent would need to parse unstructured text. |
| **No exit code semantics documented** | LOW | Scripts return 0/1 but this is not formalized in a contract. |

#### O2: Persist -- How an agent reviews past runs

| Gap | Severity | Description |
|-----|----------|-------------|
| **No log directory** | CRITICAL | `.harness/observability/logs/` does not exist. No persistent test run history. |
| **No log capture wrapper** | HIGH | No `tee`-based log capture for lint runs. Previous `test-auto.sh` is gone. |

#### O3: Queryable -- How an agent searches history

| Gap | Severity | Description |
|-----|----------|-------------|
| **No log query tool** | CRITICAL | The `log.sh` script (recent/search/follow/list/summary) is absent. An agent cannot search past runs for patterns like "FAIL" or a specific rule violation. |
| **No `jq`-parseable format** | HIGH | No structured log format (JSONL) for machine querying. |

#### O4: Attribute -- How an agent correlates runs

| Gap | Severity | Description |
|-----|----------|-------------|
| **No correlation IDs** | HIGH | No mechanism to tag a lint run with a unique ID and trace it through logs. |
| **No trace wrapper** | HIGH | The `trace.sh` script is absent. |

### 2.3 VERIFICATION GAPS

#### V1: Exit Code

| Gap | Severity | Description |
|-----|----------|-------------|
| **No standard verification command** | CRITICAL | No `make verify` that an agent can call and trust the exit code. `check.py` does work standalone but is not wired into a standard entrypoint. |

#### V2: Semantic Output

| Gap | Severity | Description |
|-----|----------|-------------|
| **No JSON status output** | HIGH | No `health.sh` or `metrics.sh` producing machine-parseable status. The previous scaffolding had both, but they are gone. |
| **No test result schema** | MEDIUM | No defined schema for `{"status":"pass|fail","framework":"...","correlation_id":"..."}`. |

#### V3: Automated Verification

| Gap | Severity | Description |
|-----|----------|-------------|
| **No CI/CD** | CRITICAL | No `.github/workflows/`, no GitLab CI, no Jenkinsfile. Zero automated verification on commit. |
| **No pre-commit hooks** | HIGH | No `.pre-commit-config.yaml`. No git hooks to prevent committing violations. |
| **No `make test-auto`** | CRITICAL | No autonomous test runner that an agent can invoke without human intervention. |

### 2.4 INFRASTRUCTURE GAPS (Inherent to the Project)

| Gap | Severity | Description |
|-----|----------|-------------|
| **No test framework** | INHERENT | Zero test files (`*.test.ts`, `*.spec.ts`). No Jest, Vitest, or any test runner. This is a read-only recovered codebase. |
| **No type checking** | INHERENT | No `tsconfig.json`. Cannot run `tsc --noEmit`. |
| **No linter (standard)** | INHERENT | No ESLint or Prettier config. Only the custom GP lint scripts exist. |
| **No build system** | INHERENT | No TypeScript compiler config. Source was recovered from compiled output. |
| **No dependency management** | INHERENT | Root has no `package.json` with dependencies. `package/package.json` has zero runtime deps. |

---

## 3. What Was Previously Scaffolded But Lost

The previous scaffolding iteration created these artifacts (visible in the assessment report cached at `.harness/assessment-report.md`), but they **do not exist on disk**:

```
.harness/
  assessment-report.md          # The only surviving artifact (already gone now)
  controllability/
    Makefile                    # make lint/check/verify/test-auto/status/logs/health/trace/clean
    start.sh                    # CLI launch with correlation ID
    stop.sh                     # CLI process stop
    verify.sh                   # Structure + lint verification
    test-auto.sh                # Automated lint + JSON result + log capture
  observability/
    log.sh                      # recent/search/follow/list/summary
    health.sh                   # JSON health status
    trace.sh                    # Correlation ID wrapper
    metrics.sh                  # JSON project metrics
    logs/                       # Log output directory
Makefile                        # Root entry point delegating to .harness/controllability/
```

**Why it was lost**: These files were generated during a scaffolding session but never committed to git. The `.gitignore` does not exclude `.harness/`, so this was an oversight in the scaffolding workflow -- it generated files but did not persist them via git commit.

---

## 4. Scoring: Current vs. Required for Autonomous Operation

### Dimension Scores (Current State)

| Dimension | Current Level | Required Level | Gap |
|-----------|:------------:|:--------------:|:---:|
| **E1 Execute** | 1 | 2 | -1 |
| **E2 Intervene** | 2 | 2 | 0 |
| **E3 Input** | 1 | 2 | -1 |
| **E4 Orchestrate** | 1 | 2 | -1 |
| **O1 Feedback** | 2 | 2 | 0 |
| **O2 Persist** | 1 | 2 | -1 |
| **O3 Queryable** | 0 | 2 | -2 |
| **O4 Attribute** | 1 | 2 | -1 |
| **V1 Exit Code** | 1 | 2 | -1 |
| **V2 Semantic** | 1 | 2 | -1 |
| **V3 Automated** | 0 | 2 | -2 |
| **TOTAL** | **12/33** | **22/33** | **-10** |

**Overall: NOT USABLE for autonomous agent work.** 8 of 11 dimensions are below the minimum Level 2 threshold.

### Previous Assessment Claimed (from cached report)

The previous assessment report claimed scores of E=8/12, O=11/12, V=7/9 (total 26/33). Those scores reflected the state **after** scaffolding was generated, but the scaffolding was ephemeral and is now gone. The actual current scores are E=5/12, O=5/12, V=3/9.

---

## 5. Priority Remediation Plan

### Phase 1: Restore Controllability (P0 -- blocks everything)

1. **Create root `Makefile`** with `lint`, `verify`, `test-auto`, `status`, `health`, `clean` targets
2. **Create `.harness/controllability/Makefile`** with the full target set
3. **Create `verify.sh`** -- structure check + lint invocation
4. **Create `test-auto.sh`** -- lint + JSON result + log capture

### Phase 2: Restore Observability (P0 -- agent needs feedback)

5. **Create `.harness/observability/logs/`** directory
6. **Create `log.sh`** -- recent/search/follow/list/summary
7. **Create `health.sh`** -- JSON health output
8. **Create `trace.sh`** -- correlation ID wrapper
9. **Create `metrics.sh`** -- JSON project metrics

### Phase 3: Persistence (P1 -- prevents scaffolding loss)

10. **Commit scaffolding to git** -- all `.harness/` files plus root `Makefile`
11. **Add `.harness/` tracking** to `.gitignore` exceptions or commit directly

### Phase 4: Harden Verification (P2 -- enables CI)

12. **Add `--json` flag to `check.py`** for machine-parseable output
13. **Add GitHub Actions workflow** for automated lint on push
14. **Add pre-commit hook** to run GP linters before commit

---

## 6. Key Findings

1. **The lint infrastructure works.** `check.py` successfully runs 8 Golden Principle linters and detects real violations (6 GP-003 violations, 28 GP-008 violations). This is the strongest piece of existing scaffolding.

2. **The documentation is excellent.** `AGENTS.md` and `docs/` provide a comprehensive agent guide with golden principles, directory maps, and architectural patterns. This is the second strongest piece.

3. **The scaffolding was ephemeral.** All controllability and observability infrastructure was generated in a previous session but never persisted. This is the core gap -- the project has the *blueprint* (assessment report, AGENTS.md) but not the *implementation* (`.harness/` scripts).

4. **No standard dev tooling exists.** No `tsconfig.json`, no test framework, no ESLint, no CI/CD. These are inherent limitations of the project being recovered source maps rather than a development workspace. The custom GP lint scripts partially compensate for the absence of standard tooling.

5. **`trace.sh` has a bug.** The previous implementation used `${PIPESTATUS[0]}` after a `while` loop pipe, but `PIPESTATUS` is a Bash array that only captures the last pipeline's exit codes. After a `while read` loop, `PIPESTATUS[0]` captures the exit code of the subshell (`"$@"`), but this is fragile and may not work in all shells.

6. **`verify.sh` exit code logic is flawed.** The previous implementation used `set -e` combined with conditional checks that increment `ERRORS`, but `set -e` will cause the script to exit on the first failure before reaching `exit $ERRORS`. The Makefile `verify` target has a similar issue where it runs `check.py` after structure checks, but the exit code propagation uses `$$?` after a multi-line `if` block, which captures the `echo` exit code, not the `check.py` exit code.

---

## 7. File Inventory

### Existing Scaffolding (on disk)

| File | Purpose | Works? |
|------|---------|--------|
| `rules/_registry.json` | Rule registry (8 rules) | Yes |
| `rules/common/golden-principles/GP-001..008.md` | Rule definitions | Yes |
| `rules/scripts/check.py` | Lint orchestrator | Yes (6 pass, 2 fail) |
| `rules/scripts/lint-gp001..008.sh` | Individual lint scripts | Yes |
| `AGENTS.md` | Agent guide | Yes |
| `docs/reference/*.md` (6 files) | Architecture docs | Yes |
| `docs/guides/*.md` (3 files) | How-to guides | Yes |
| `.claude/settings.local.json` | Local permissions | Yes |

### Missing Scaffolding (not on disk)

| File | Purpose | Previously existed? |
|------|---------|---------------------|
| `Makefile` (root) | Agent entrypoint | Yes (ephemeral) |
| `.harness/controllability/Makefile` | Harness targets | Yes (ephemeral) |
| `.harness/controllability/verify.sh` | Structure + lint check | Yes (ephemeral) |
| `.harness/controllability/test-auto.sh` | Automated test runner | Yes (ephemeral) |
| `.harness/controllability/start.sh` | CLI launcher | Yes (ephemeral) |
| `.harness/controllability/stop.sh` | CLI stopper | Yes (ephemeral) |
| `.harness/observability/log.sh` | Log query tool | Yes (ephemeral) |
| `.harness/observability/health.sh` | JSON health check | Yes (ephemeral) |
| `.harness/observability/trace.sh` | Correlation ID wrapper | Yes (ephemeral) |
| `.harness/observability/metrics.sh` | JSON metrics | Yes (ephemeral) |
| `.harness/observability/logs/` | Log storage | Yes (ephemeral) |
| `.github/workflows/*.yml` | CI pipeline | Never created |
| `.pre-commit-config.yaml` | Pre-commit hooks | Never created |
| `tsconfig.json` | Type checking | Never created |
| `*.test.ts` / `*.spec.ts` | Test files | Never created |
