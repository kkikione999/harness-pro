---
name: harness-pro-execute-task
description: >
  Execute implementation plans using TDD discipline with DAG orchestration and milestone reviews.
  Use this skill whenever: you have a plan.md (from create-plan or docs/features/{id}/plan.md) and need
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

    FIRST: Read the shared context from .harness/file-stack/{feature-id}/context.md
    This contains patterns, conventions, and insights from the plan agent — use it to understand the codebase before diving in. Also append any new discoveries to the `## Worker Discoveries` section using the format: `- [M{N}] {discovery}`.
    Only touch the listed files. Run tests after each step.
    If blocked, stop and report back. Do NOT read the full plan — only your assigned steps.

    Behavioral rules:
    - Think before coding: state assumptions, resolve ambiguity by reading code, push back if plan doesn't match reality.
    - Simplicity: every line traces to a Change entry. No speculative features, no abstractions for single-use code.
    - Surgical: don't improve adjacent code. Match existing style. Remove only orphans YOUR changes created.
    - Goal-driven: each step needs a verifiable check. Loop until verified.

    When done: append discoveries to context.md's Worker Discoveries section, then TaskUpdate completed, message lead with summary.
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

### Step 2.5: Lint at Milestone Boundaries

After each worker completes a milestone and BEFORE spawning the reviewer, run computational sensors. These catch mechanical issues cheaply and fast, so the reviewer can focus on architecture and spec compliance.

Run two things:

1. **P0 universal checks** (always, all projects):
   ```bash
   bash .claude/skills/harness-pro-execute-task/scripts/p0-checks.sh
   ```
   This script checks: hardcoded secrets (P0-001), file size limit 800 lines (P0-002), TODO/FIXME residuals (P0-003), Worker Discoveries append (P0-004).

2. **Project-specific lint** (if available): Read `CLAUDE.md` Development section for the lint command. If not found, read `references/p0-lint-guide.md` for auto-detection patterns.

CRITICAL violations from P0 checks → fix before reviewer. Project lint errors → fix before reviewer. P0-004 Worker Discoveries warnings → log and continue (advisory only).

### Step 3: Milestone Review

After lint passes, spawn a **fresh reviewer Agent** (not the worker, not the coordinator — a clean perspective):

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
2. All pass → update `.harness/file-stack/{feature-id}/documentation.md` with completion status → shut down team → invoke harness-pro-complete-work
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

During execution, maintain `.harness/file-stack/{feature-id}/`:

| File | When to Update | What to Write |
|------|---------------|---------------|
| `context.md` | Read first at start | Patterns, conventions, gotchas from plan agent (READ this before reading source files) |
| `prompt.md` | Once at start | Original requirement + feature summary |
| `plan.md` | After each milestone | Check off completed steps |
| `documentation.md` | At milestones and significant events | Decisions made, surprises found, current status |

**context.md is the key knowledge-transfer layer**: the plan agent's discoveries live here. Workers READ it first, then append surprises/gotchas they encounter so future workers (or milestone reviewers) benefit.

## Behavioral Guidelines for Workers

These guidelines bias toward caution over speed. For truly trivial tasks, use judgment — but default to caution.

### 1. Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

Before implementing each change:
- State your assumptions explicitly. If uncertain, investigate the code first.
- If multiple interpretations of the plan exist, read the code to resolve ambiguity. If still unclear, report back — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something in the plan doesn't match reality, stop. Name what's confusing. Report back.

### 2. Simplicity First

Minimum code that solves the problem. Nothing speculative.

- Every line of code must trace back to a specific Change entry in the plan.
- No features beyond what was asked. No "flexibility" or "configurability" that wasn't requested.
- No abstractions for code used only once. No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.
- Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

Touch only what you must. Clean up only your own mess.

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to a Change entry in the plan.

### 4. Goal-Driven Execution

Define success criteria. Loop until verified.

Transform plan steps into verifiable goals:

| Vague goal | Verifiable goal |
|---|---|
| "Add validation" | "Write tests for invalid inputs, then make them pass" |
| "Fix the bug" | "Write a test that reproduces it, then make it pass" |
| "Refactor X" | "Ensure tests pass before and after" |

For multi-step work, state a brief plan with verification checkpoints:

```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification — so define them upfront.

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
  Workers complete → run P0 checks + project lint
        ↓
  Lint passes → spawn reviewer Agent for each milestone
        ↓
  Fix CRITICAL/HIGH issues → unblock next milestones → spawn next workers
        ↓
  All milestones done → run full Validation
        ↓
  Shut down team → AUTOMATIC: invoke harness-pro-complete-work
```
