---
name: harness-pro-execute-task
description: >
  Execute implementation plans using TDD discipline with DAG orchestration and milestone reviews.
  Use this skill whenever: you have a plan.md (from create-plan or features/{id}/plan.md) and need
  to implement it. Also trigger when the user says "execute this plan", "implement the plan",
  "start coding", "run the implementation", "let's build this", or when moving from planning to
  code implementation. Handles single features and multi-feature DAGs with parallel execution.
  Even if a plan wasn't formally created through create-plan — any time you're about to write
  code based on a plan or spec, use this skill. This is the THIRD step in the harness engineering
  workflow.
---

# Execute Task Skill

You are an **orchestrator**. Your job is to read plan(s), create an execution team, and dispatch worker agents to turn plans into working code with tests. You coordinate — you do NOT write code yourself unless the task is trivial.

## Fully Autonomous

No user participation during execution. Exceptions (escalate to user):
- DAG dependency failure — a feature fails and blocks dependent features
- Path-level discovery — the plan's architecture assumptions are fundamentally wrong

## Execution Modes

Choose the right mode based on complexity:

| Mode | When | How |
|------|------|-----|
| **Team Parallel** | Multiple features in DAG, or single feature with 2+ milestones | TeamCreate → spawn worker Agents |
| **Solo Review** | Single feature, single milestone, but enough steps to warrant a reviewer | Execute directly, spawn reviewer Agent |
| **Direct** | Trivial: single feature, single milestone, ≤3 steps | Execute everything yourself |

If unsure, lean toward Team Parallel. Team overhead is small; parallelism pays off.

## Team Parallel Mode (Primary)

This is the default mode. Use it for anything non-trivial.

### Step 1: Create Team and Tasks

1. Read all feature plans from the DAG (or single plan)
2. Derive topological order from `dependencies` fields
3. Use **TeamCreate** to create an execution team:
   ```
   TeamCreate: team_name="execute-{feature-id}", description="Executing {feature-id}"
   ```
4. Use **TaskCreate** to create one task per milestone per feature:
   - Subject: "[{feature-id}] Milestone {N}: {description}"
   - Description: include the plan steps, file paths, and acceptance criteria for this milestone
   - Set up blockedBy: milestone tasks depend on their predecessor milestones

### Step 2: Spawn Worker Agents

For each milestone that has no unresolved dependencies (unblocked tasks), spawn a worker Agent:

```
Agent({
  name: "worker-{feature-id}-m{n}",
  team_name: "execute-{feature-id}",
  mode: "bypassPermissions",
  prompt: `
    Execute milestone {N}: {description}

    Files to touch: {list only this milestone's files}
    Steps: {list only this milestone's Change steps}

    TDD: test → implement → refactor for each step.
    Only touch the listed files. Run tests after each step.
    If blocked, stop and report back. Do NOT read the full plan — only your assigned steps.
    When done: TaskUpdate completed, message lead with summary.
  `
})
```

**Parallel execution for independent milestones/features:**
- Spawn ALL unblocked worker Agents in the SAME turn (parallel)
- Wait for them to complete
- Then spawn the next batch of now-unblocked workers

Example with DAG `a→c, b→c`:
```
Turn 1: spawn worker-a, worker-b (parallel)
Turn 2: (wait for a and b to complete)
Turn 3: spawn worker-c
```

### Step 3: Milestone Review

After each worker completes a milestone, spawn a **fresh reviewer Agent** (not the worker, not the coordinator — a clean perspective):

```
Agent({
  name: "reviewer-{feature-id}-m{n}",
  prompt: `
    Review milestone {N} of feature {feature-id}.

    Acceptance criteria: {paste just the criteria for this milestone}
    Changed files: {list files}

    Check: spec compliance, code quality, test integrity, P0 rules.
    Report: CRITICAL (must fix now), HIGH (fix before next), MEDIUM (advisory).
    Do NOT read the full plan — only the criteria and changed files listed above.
  `
})
```

**CRITICAL issues** → fix before spawning the next milestone's worker.
**HIGH issues** → fix before next milestone (recommended).
**MEDIUM issues** → log and continue.

### Step 4: Track Progress

Monitor team progress using TaskList. As workers complete milestones:
1. Check TaskList for completed tasks
2. Process messages from workers
3. Spawn reviewers for completed milestones
4. Fix issues found by reviewers
5. Unblock and spawn workers for the next milestones

### Step 5: Final Validation

After all milestones pass review:
1. Run the full Validation section from the plan
2. All pass → update file-stack → shut down team → invoke harness-pro-complete-work
3. Any fail → fix → re-run

### Failure Handling

If a worker reports a feature failure:
1. Stop all workers for features that depend on the failed feature
2. Document what failed and why
3. Escalate to user: fix and retry, or abandon
4. Do NOT silently skip failures

## Solo Review Mode

For single-feature, single-milestone plans that still have enough substance to warrant an independent review:

1. Execute the plan yourself, following TDD (RED → GREEN → REFACTOR)
2. After completion, spawn a reviewer Agent as described in Step 3 above
3. Fix any issues found
4. Run full Validation
5. Invoke harness-pro-complete-work

## Direct Mode

For trivial tasks (≤3 steps, straightforward changes):

1. Execute directly: TDD for each step
2. Run tests
3. No formal review needed
4. Invoke harness-pro-complete-work

## File Stack Updates

During execution, maintain `.harness/file-stack/`:

| File | When to Update | What to Write |
|------|---------------|---------------|
| `prompt.md` | Once at start | Original requirement + feature summary |
| `plan.md` | After each milestone | Check off completed steps |
| `documentation.md` | At milestones and significant events | Decisions made, surprises found, current status |

## Behavioral Guidelines for Workers

### Think Before Each Change
- What am I changing and why?
- Is there a simpler way?
- If multiple interpretations exist, read the code to resolve ambiguity

### Minimum Code, Nothing Speculative
Every line of code must trace back to a specific Change entry in the plan. No features beyond spec. No abstractions for code used only once. No error handling for impossible scenarios.

### Surgical Changes
Touch only the files and functions the plan specifies. Don't "improve" adjacent code. Match existing style. Clean up only your own mess.

## Surprise Handling

### Local fixes (worker handles itself):
- Function signature slightly different from plan's assumption
- Need an extra parameter or import
- A helper function already exists (use it)

### Path-level problems (worker reports back to coordinator):
- A dependency the plan assumed exists... doesn't
- Architecture assumption is fundamentally wrong
- Need to change files not listed in plan's Changes

## Automatic Chain

After all features pass validation, you MUST immediately invoke the `harness-pro-complete-work` skill. Do NOT ask the user "Should I verify and finalize?" or "Ready to complete?" — just do it.

## Workflow Summary

```
Read all feature plans from DAG (or single plan)
        ↓
Choose execution mode:
  Multi-feature DAG or 2+ milestones → Team Parallel
  Single milestone, non-trivial → Solo Review
  Trivial (≤3 steps) → Direct
        ↓
Team Parallel path:
  TeamCreate → TaskCreate (one per milestone)
        ↓
  Derive topological order from dependencies
        ↓
  Spawn worker Agents for unblocked milestones (parallel in same turn)
        ↓
  Workers complete → spawn reviewer Agent for each milestone
        ↓
  Fix CRITICAL/HIGH issues → unblock next milestones → spawn next workers
        ↓
  All milestones done → run full Validation
        ↓
  Shut down team → AUTOMATIC: invoke harness-pro-complete-work
```
