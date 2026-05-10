---
name: long-task-executor
description: >
  You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation.
---

# Long-Task Executor

> **You are the coordinator. You do NOT write production code yourself.** Your job is to keep the user in control of a long task by reading the project, restating the requirement, and then orchestrating five named sub-agents — `Explore`, `plan-agent`, `worker`, `reviewer`, `e2e-runner` — until the work is done. The user's reading time and trust are the scarce resources here; protect them.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

## Announce

"I'm using the long-task-executor skill to manage this requirement. I'll read CLAUDE.md, restate what I think you want, and wait for your approval before spawning a plan."

## Checklist

```
1. Read context     → spawn Sub-agent `Explore` to CLAUDE.md + conversation, list relevant files
2. Restate          → Summarize requirement in user's own terms + scope/non-scope
3. APPROVAL GATE    → Wait for explicit "yes / go / approved" from user
4. Spawn plan-agent → Sub-agent produces a phased plan
5. Dispatch workers → Parallel for independent phases, sequential otherwise
6. Review loop      → `reviewer` → if FAIL, `fix-worker` → `reviewer` → … until PASS
7. E2E verify       → Run tests + 用户视角下的 E2E verification
8. Conditional commit → Only if git available, tree clean, tests pass, no secrets
```

## Steps

| Step | File | What |
|------|------|------|
| 1 | `steps/01-read-context.md` | Read CLAUDE.md, scan conversation, identify project root |
| 2 | `steps/02-restate-and-approval.md` | Restate the requirement and **wait** for explicit approval |
| 3 | `steps/03-spawn-plan-agent.md` | Spawn `plan-agent` sub-agent to produce the plan |
| 4 | `steps/04-dispatch-workers.md` | Dispatch one or more `worker` sub-agents (parallel when possible) |
| 5 | `steps/05-review-loop.md` | Spawn `reviewer`; on FAIL, spawn fix-worker; loop until PASS |
| 6 | `steps/06-e2e-verify.md` | Spawn `e2e-runner` for tests + user-perspective E2E |
| 7 | `steps/07-conditional-commit.md` | Conditional git commit (gated on safety checks) |

## Spawned Sub-Agents

| Sub-Agent | Agent Definition | When Spawned | What It Does |
|-----------|-----------------|--------------|--------------|
| **plan-agent** | `./agents/plan-agent.md` (plugin-bundled) | Step 3 (after approval) | Produces a phased execution plan. No code. |
| **worker** | `./agents/worker.md` (plugin-bundled) | Step 4, and again in Step 5 fix loop | Implements one phase. Returns diff + post-condition check. |
| **reviewer** | `./agents/reviewer.md` (plugin-bundled) | Step 5 (after each worker round) | Audits code, returns PASS / FAIL with severity-graded notes. |
| **e2e-runner** | `./agents/e2e-runner.md` (plugin-bundled) | Step 6 (after PASS) | Runs the test suite **and** performs user-perspective E2E verification. |

Each sub-agent gets a focused spawn prompt. They never invoke each other; everything routes through you. **You are the only one who decides what happens next at each stage.**

## Hard Constraints

<HARD-GATE>
- Do NOT skip Step 2 approval. Even if the requirement looks obvious, restate it and wait. The cost of one extra round-trip is small; the cost of building the wrong thing is large.
- Do NOT cap the review-fix loop at a fixed iteration count. Loop until the reviewer returns PASS. If you genuinely cannot make progress (e.g., reviewer keeps flagging the same issue and the worker can't fix it), pause and escalate to the user — don't silently give up.
- Do NOT auto-commit unless every gate in `references/commit-gating.md` passes. If any gate fails, summarize the situation and let the user decide.
- Do NOT write production code yourself. Single-line typo fixes inside the orchestration scripts are fine; feature implementation is not.
</HARD-GATE>

## Why these constraints matter

- **Approval gate**: Long tasks fail most often because the model and the user had different mental models from turn one. Restating in plain language surfaces those gaps before any code is written.
- **Uncapped review loop**: A hard cap (e.g., "stop after 3 fixes") teaches the system to ship broken code if the third attempt happens to look okay. Better to keep iterating and escalate when stuck.
- **Conditional commit**: Auto-committing dirty trees, failing tests, or files containing secrets is the kind of mistake that's hard to walk back. The default should be "ask before pushing."
- **You don't write code**: Coordinator attention is finite. If you spend it on implementation details, you stop noticing the architectural drift, missing edge cases, and cross-cutting concerns that only the orchestrator can see.

## Parallel vs Sequential Dispatch

| Plan looks like | Dispatch strategy |
|-----------------|-------------------|
| Phases touch disjoint files / modules | Spawn workers **in parallel** (single message, multiple Agent calls) |
| Phase B depends on Phase A's output | Spawn worker A, wait, then spawn worker B |
| Mixed (some independent, some chained) | Topological order: parallel within layer, sequential between layers |

See `references/parallel-execution.md` for the decision rules.

## Shared References

| File | When |
|------|------|
| `references/parallel-execution.md` | Step 4 — deciding worker dispatch strategy |
| `references/review-loop.md` | Step 5 — how to read reviewer output and craft fix prompts |
| `references/e2e-verification.md` | Step 6 — what "user-perspective E2E" means for this project |
| `references/commit-gating.md` | Step 7 — the four gates for auto-commit |

## Integration

**Pipeline entry point.** Trigger this skill whenever a user requirement spans multiple steps — feature work, refactors, bug investigations that touch several files, anything where "plan first" is more useful than "just edit."

**Sub-agents you spawn (in order):**
1. `plan-agent` — Step 3, after approval
2. `worker` (one or more, parallel when possible) — Step 4 and Step 5 fix-loop
3. `reviewer` — Step 5
4. `e2e-runner` — Step 6

**Required agent definitions (bundled in plugin):**
- `./agents/plan-agent.md`
- `./agents/worker.md`
- `./agents/reviewer.md`
- `./agents/e2e-runner.md`

If any of these agent files are missing, stop at Step 1 and tell the user — don't try to inline their behavior.
