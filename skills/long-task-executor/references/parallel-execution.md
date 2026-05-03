# Parallel Worker Execution

When you have a multi-phase plan, the question is: spawn workers in parallel, sequentially, or some mix?

## The decision rule (short version)

```
For each phase pair (A, B):
  if A.files ∩ B.files != ∅            → sequential
  if B.depends_on contains A           → sequential
  if A's output is B's input           → sequential
  otherwise                            → parallel
```

Apply this transitively. The result is a DAG; you spawn one "layer" at a time, parallel within a layer, sequential between layers.

## Worked example

Plan:
- Phase 1: add `src/types/User.ts`
- Phase 2: add `src/utils/email.ts` (no deps on Phase 1)
- Phase 3: add `src/api/users.ts` — imports both User and email helper
- Phase 4: add `src/api/users.test.ts` — depends on Phase 3

Layer analysis:
- Layer 0: Phases 1 and 2 (independent, can run parallel)
- Layer 1: Phase 3 (depends on 1 and 2)
- Layer 2: Phase 4 (depends on 3)

Dispatch:
1. Spawn worker-1 (Phase 1) and worker-2 (Phase 2) in parallel — single message, two `Agent` calls.
2. After both return: spawn worker-3 (Phase 3).
3. After worker-3 returns: spawn worker-4 (Phase 4).

## How to actually invoke parallel workers

In a single assistant turn, emit multiple `Agent` tool calls. Each one is a separate sub-agent that runs concurrently:

```
[Agent call 1] subagent_type=worker, prompt=Phase 1 spawn prompt
[Agent call 2] subagent_type=worker, prompt=Phase 2 spawn prompt
```

Don't do:
```
[Agent call 1] Phase 1
…wait for it to return…
[Agent call 2] Phase 2
```

The second pattern is sequential and wastes wall-clock time when the phases were independent.

## When to default to sequential

- The plan has fewer than 3 phases — the parallelism overhead isn't worth it
- You can't be sure files don't overlap (e.g., the plan says "modify config" without specifying which file)
- The project has shared mutable state that doesn't tolerate concurrent edits (rare, but possible — e.g. some monorepo lockfiles)
- You're inside a Step 5 fix loop — fixes touch what the reviewer flagged, which is rarely independent enough to parallelize

When in doubt: sequential. The cost of "took longer than necessary" is low; the cost of "two workers stomped on each other" is high.

## What about the fix loop

The Step 5 fix loop is normally sequential: one worker fix per review round. If the reviewer's feedback is genuinely independent (e.g., "issue A in file X" and "unrelated issue B in file Y") and you've confirmed the workers won't conflict, you can parallelize. This is rare; default to one fix-worker per loop iteration.
