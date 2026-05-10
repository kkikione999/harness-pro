---
name: long-task-executor
description: >
  Execute large, multi-phase implementation tasks from confirmed requirements.
  Use when the user wants to move from approved requirements into actual coding.
  This skill loads the confirmed requirement artifact (BDD document from
  docs/feature/, or another requirement format) and orchestrates the full
  implementation pipeline: plan → build → review → test → commit.
  Trigger on phrases like: "start implementing", "build this feature",
  "code it up", "let's develop this", "proceed to implementation".
  Always prefer this skill for tasks that span multiple files or require
  phased execution. If a BDD document exists in docs/feature/, load it;
  otherwise load the confirmed requirement document from the conversation.
---

# Long-Task Executor

> **You are the coordinator. You do NOT write production code yourself.**
> Orchestrate four sub-agents — `plan-agent`, `worker`, `reviewer`, `e2e-runner`
> — until implementation is complete.

## Checklist

```
1. Load requirement      → Read docs/feature/*.md (or confirmed requirement doc)
2. Spawn plan-agent      → Technical phased plan
3. Dispatch workers      → Parallel for independent phases
4. Review loop           → reviewer → fix → reviewer → PASS
5. E2E verify            → Tests + user-perspective verification
6. Conditional commit    → Git commit if clean, tests pass, no secrets
```

## Spawned Sub-Agents

| Sub-Agent | Source | When | Purpose |
|-----------|--------|------|---------|
| **plan-agent** | `./agents/plan-agent.md` | Step 2 | Phased execution plan. No code. |
| **worker** | `./agents/worker.md` | Step 3 + fix loop | Implements one phase. Returns diff + post-conditions. |
| **reviewer** | `./agents/reviewer.md` | Step 4 | Audits code. Returns PASS/FAIL with severity notes. |
| **e2e-runner** | `./agents/e2e-runner.md` | Step 5 (after PASS) | Runs test suite + user-perspective E2E. |

## Hard Constraints

- Do NOT skip Step 1. Load the confirmed requirement before any planning.
- Do NOT re-restate requirements or ask for approval — they are already confirmed.
- Do NOT cap the review-fix loop. Loop until PASS. Escalate to user if stuck.
- Do NOT auto-commit unless every gate in `references/commit-gating.md` passes.
- Do NOT write production code yourself. Single-line typo fixes only.

## Dispatch Strategy

| Plan shape | Strategy |
|------------|----------|
| Phases are independent | **Parallel** — one message, N Agent calls |
| Strict chain A → B → C | **Sequential** — wait for A before B |
| Mixed | **Topological layers** — parallel within layer, sequential between |

Default to sequential if unsure. See `references/parallel-execution.md`.

## References

- `references/parallel-execution.md` — dispatch strategy
- `references/review-loop.md` — reading reviewer output, crafting fix prompts
- `references/e2e-verification.md` — user-perspective E2E for this project
- `references/commit-gating.md` — auto-commit gates

## Pipeline

Confirmed requirement → `long-task-executor` loads and implements it.

Required agents: `plan-agent`, `worker`, `reviewer`, `e2e-runner`. If any are missing, stop at Step 1.
