# Progressive Scaffolding Assessment Report
# Open-ClaudeCode

**Project:** Open-ClaudeCode  
**Path:** /Users/josh_folder/Open-ClaudeCode  
**Type:** TypeScript CLI (CLI reconstruction of Claude Code CLI v2.1.88)  
**Date:** 2026-04-09T20:56:10+08:00  
**Skill Version:** v1 (wrapper scripts / surface layer)  
**Model:** sonnet  

---

## Executive Summary

Open-ClaudeCode is a TypeScript + React/Ink terminal CLI with 1,888+ source files. The project has **strong existing observability** (telemetry infrastructure, analytics, cost tracking) but **no test infrastructure**, **no CI/CD**, and **delegates control to a non-existent `.harness/` directory** via the Makefile. This scaffolding gap means the Makefile targets (`run`, `verify`, `test-auto`, `logs`) all fail.

**Overall Score: 26/33** (E:8/12, O:12/12, V:6/9)

---

## Assessment Dimensions

### Controllability (E1-E4) — Score: 8/12

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **E1 Execute** | 2/3 | Makefile found with `run`, `test`, `verify` targets. No npm/go build system (no package.json, no go.mod). Score capped at L2. |
| **E2 Intervene** | 2/3 | Directory is writable; Makefile allows script delegation. No process management (no Docker). |
| **E3 Input** | 2/3 | Rules system exists (`rules/`), config via env/hooks. No structured `.env` or `config.json` found. |
| **E4 Orchestrate** | 2/3 | Makefile chains commands. No Docker Compose. Single-process only. |

**Key Gap:** The Makefile delegates to `.harness/controllability/` which does not yet exist — all Makefile targets are broken.

### Observability (O1-O4) — Score: 12/12

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **O1 Feedback** | 3/3 | **Excellent.** `src/utils/telemetry/` (9 files), `src/services/analytics/` (9 files), structured cost-tracking (`costHook.ts`, `cost-tracker.ts`), profiler base. Console output exists. |
| **O2 Persist** | 3/3 | **Excellent.** Telemetry persistence infrastructure, `profilerBase.ts`, analytics exporters. |
| **O3 Queryable** | 3/3 | **Excellent.** Structured telemetry with attributes allows log aggregation. |
| **O4 Attribute** | 3/3 | **Excellent.** `telemetryAttributes.ts`, correlation/tracing patterns, session tracking. |

**Key Finding:** Open-ClaudeCode already has strong observability at the source level. The gap is **exposing** it via wrapper scripts so agents can query it programmatically.

### Verification (V1-V3) — Score: 6/9

| Dimension | Level | Evidence |
|-----------|-------|----------|
| **V1 Exit Code** | 2/3 | Makefile exists. **No test framework** (AGENTS.md notes: "no build/test infrastructure available"). |
| **V2 Semantic** | 2/3 | Telemetry infrastructure suggests structured output capability. |
| **V3 Automated** | 2/3 | Makefile has `test-auto` target. **No CI/CD** (no `.github/workflows/`). |

**Key Gap:** No test runner, no CI pipeline. The `test-auto` Makefile target calls `.harness/controllability/test-auto.sh` which does not exist.

---

## Priority Gaps (Ranked by Impact)

### P0 — Broken Makefile (blocks all automation)
The root Makefile delegates to `.harness/` which does not exist:
```
run:       → $(HARNESS)/start.sh     (MISSING)
verify:    → $(HARNESS)/verify.sh    (MISSING)
test-auto: → $(HARNESS)/test-auto.sh (MISSING)
lint:      → $(HARNESS)/lint-check.sh (MISSING)
logs:      → .harness/observability/log.sh (MISSING)
```
**Fix:** Generate `.harness/` wrapper scripts.

### P1 — No Test Infrastructure
AGENTS.md explicitly states: "no build/test infrastructure available."  
No jest, vitest, or any test runner.  
**Fix:** Add test-auto.sh that exits 1 with a "no tests" message for agent loop clarity.

### P2 — No CI/CD Pipeline
No `.github/workflows/`. The `ci-pipeline.yml` template exists but is not deployed.  
**Fix:** Generate CI template (optional, deploy manually).

### P3 — Limited Structured Logging for Agents
Existing telemetry is source-internal. Agents need wrapper scripts to query it without reading source code.  
**Fix:** `log.sh`, `trace.sh`, `health.sh` scripts that wrap around existing telemetry.

---

## Behavioral Gap Matrix

```
Controllability:
  E1 Execute:         2/3  — Makefile exists, no package.json
  E2 Intervene:       2/3  — Writable, no process management
  E3 Input:           2/3  — Rules system, no structured config
  E4 Orchestrate:     2/3  — Makefile, no multi-service

Observability:
  O1 Feedback:        3/3  — telemetry/, analytics/, cost-hooks
  O2 Persist:         3/3  — profilerBase, telemetry persistence
  O3 Queryable:       3/3  — Structured telemetry attributes
  O4 Attribute:       3/3  — telemetryAttributes.ts, session tracking

Verification:
  V1 Exit Code:      2/3  — Makefile, no test runner
  V2 Semantic:        2/3  — Structured telemetry
  V3 Automated:       2/3  — Makefile targets, no CI
```

---

## Recommended Starting Tier

**Tier 0 (Surface Wrapper):** Generate `.harness/` wrapper scripts.  
This is the v1 approach — surface wrappers only, zero intrusion into source code.  
The existing telemetry is excellent; we just need wrapper scripts to expose it.

Estimated changes:
- New files: 10 (controllability + observability + CI)
- Lines added: ~400 shell script lines
- Source changes: **0 lines** (zero intrusion)

---

## What Exists (Don't Re-invent)

- `src/utils/telemetry/` — 9 files of telemetry infrastructure
- `src/services/analytics/` — 9 files of analytics service
- `src/costHook.ts`, `src/cost-tracker.ts` — Cost tracking hooks
- `src/utils/telemetryAttributes.ts` — Structured attribute system
- `src/utils/profilerBase.ts` — Profiler infrastructure
- `rules/` — Agent rules system (already harness-ready)

---

## Telemetry Infrastructure Details

```
src/utils/telemetry/         (9 files)
src/services/analytics/      (9 files)
src/utils/telemetryAttributes.ts
src/utils/profilerBase.ts
src/services/api/metricsOptOut.ts
src/costHook.ts
src/cost-tracker.ts
src/commands/cost/cost.ts
```

---

*Report generated by progressive-scaffolding v1 skill*
*Model: sonnet*
