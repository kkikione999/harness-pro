# Step 4 — Dispatch Workers

Goal: execute the plan by spawning one or more `worker` sub-agents, in parallel when phases are independent.

## Decide the dispatch strategy

Before spawning anything, look at the plan's phase dependencies. See `references/parallel-execution.md` for the full decision tree, but the short version:

| Plan shape | Strategy |
|------------|----------|
| All phases independent (no shared files, no `depends-on` edges) | **Parallel** — one message, N Agent calls |
| Strict chain A → B → C → … | **Sequential** — wait for A's diff before B starts |
| Mixed | **Topological layers** — parallel inside each layer, sequential between layers |

Default to sequential if you're unsure. Parallel saves wall-clock time but multiplies blast radius if one worker corrupts shared state.

## How to spawn each worker

Use `Agent` with `subagent_type: "worker"`. The spawn prompt for each worker should contain:

- **Plan file path** — so the worker can read the full context
- **Phase number(s) it owns** — be explicit, e.g. "Phase 2 only"
- **Forbidden files** — anything the plan flagged as out-of-scope or owned by another worker in a parallel layer
- **Post-conditions** — copied from the plan, so the worker knows what "done" means

Example:

```
You are a worker sub-agent. Load ~/.claude/agents/worker.md.

# Plan
/path/to/plan.md

# Your phase(s)
Phase 2: implement the rate-limit middleware in src/middleware/rate-limit.ts

# Forbidden
- Anything outside src/middleware/
- The Phase 1 worker is editing src/config/, do not touch it

# Post-conditions
- New file src/middleware/rate-limit.ts exports `rateLimit(opts)` factory
- Existing tests still pass
- New unit test in src/middleware/rate-limit.test.ts covers the burst case

Return: list of files changed, diff summary, post-condition check results.
```

## What workers return

Each worker returns:
- Files changed (`git diff --name-only`)
- Brief diff summary
- Post-condition self-check (pass/fail per condition)
- Any issues or surprises they hit

Collect all worker outputs before moving on. If any worker reports a blocking surprise (e.g., "the plan said use library X but X doesn't exist"), pause and either:
1. Re-spawn the plan-agent with the new information, or
2. Surface it to the user if it changes the requirement

Don't silently let the worker improvise around plan failures.

## After all workers return

Move to Step 5 (review loop). Don't run tests yet — that's the teammate's job in Step 6, after the reviewer is satisfied.

## Edge cases

- **Worker crashes / returns empty diff**: re-spawn once with the same prompt. If it fails again, treat as blocking and surface to user.
- **Two parallel workers touch the same file**: this is a planning bug. Re-spawn the plan-agent to split or serialize the phases.
- **A worker says the phase is impossible as specified**: pause; this is plan-level feedback, route it back to the plan-agent.
