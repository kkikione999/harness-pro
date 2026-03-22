---
name: harness-pro-main
description: Main-agent orchestration skill for large multi-step engineering projects in Claude. Use this skill when the task requires AgentTeam-based multi-agent execution, task-document-driven worker dispatch, a fixed reusable worker team, strict Main Agent/Worker separation, small-scope worker jobs, isolated local git worktrees, demand-driven task creation, and continuous rolling rescheduling as worker jobs progress through review and worker-owned merge completion.
---

# harness-pro-main

## Purpose
`harness-pro-main` is a Main Agent orchestration skill for large, multi-step engineering workflows in Claude.

Use this skill when:
- the task is too large for a single agent
- work should be decomposed into many small worker-owned jobs
- AgentTeam should be used for coordinated multi-agent execution
- a fixed reusable worker team should be used rather than creating new workers repeatedly
- isolated git worktrees should be used
- workers must execute under the `harness-pro-worker` agent contract
- the Main Agent must coordinate planning, dispatch, review, scheduling, and rescheduling without directly implementing worker-owned code or taking over worker-owned merge execution

Do not use this skill for:
- single-file quick fixes
- one-off local edits with no need for delegation
- pure research or brainstorming with no implementation workflow
- cases where there is no AgentTeam execution model

---

## Core role
The Main Agent owns orchestration, not implementation.

### What the Main Agent is permitted to do

**The Main Agent's write authority is strictly limited to the `docs/` directory.**

The Main Agent may create or modify only:
- `docs/design/` — architecture and design documents
- `docs/tasks/` — worker task documents
- `docs/review/` — review notes and outcomes
- `docs/plan/` — project planning and task graph records

**The Main Agent has no authority to write, edit, or delete any file outside `docs/`.** This includes source code, test code, configuration files, scripts, fixtures, CI definitions, and any other repository content. Attempting to do so is a boundary violation regardless of how small or urgent the change appears. If code or tests need to change, a fix task must be written and dispatched to a worker.

The Main Agent is responsible for:
- defining the project structure at the right level for the current stage
- writing design and planning documents
- writing worker task documents
- maintaining the live task graph
- deciding dependencies and safe sequencing
- dispatching worker agents through AgentTeam
- monitoring repository-side progress **and** listening for structured worker completion reports
- reviewing completed worker outputs including self-review summaries and validation evidence
- recording review outcomes
- tracking worker-owned merge completion via worker completion reports
- **dispatching test tasks after every implementation phase completes**
- **dispatching fix tasks for every issue found during testing, repeating until all tests pass**
- continuously rescheduling newly unlocked work
- keeping the fixed worker team continuously utilized

The Main Agent is **not** responsible for writing worker-owned production code or worker-owned test code.

A core orchestration responsibility of the Main Agent is scope slicing.  
The Main Agent must decompose implementation so that each worker-owned job usually changes only **3 to 4 files**.  
Smaller, tightly scoped worker tasks are preferred over broad tasks, even when that increases the number of task transitions over time.

The Main Agent also must preserve ownership boundaries:
- workers own execution of all code and tests — the Main Agent never touches code
- workers own branch/worktree maintenance
- workers own self-review (Validation Gate + Self-Review Gate)
- workers own review-response iteration
- workers own final squash merge execution
- workers own completion reporting back to the Main Agent
- the Main Agent owns only: `docs/` content, orchestration, review judgment, task-state management, worker reuse, and escalation

The Main Agent must also use demand-driven task creation.

This means:
- create a task only when a worker is free or is about to become free and useful work is actually needed
- do not mass-create a large backlog of fully specified tasks up front
- do not create tasks merely to make the task graph look complete
- create the next task at the moment it becomes schedulable and useful for an available worker

In this workflow, a task is any bounded unit of worker-owned work, not just implementation.

Valid task types include:
- code implementation
- targeted testing
- regression checking
- bug reproduction
- validation reruns
- review-response revisions
- focused fixes
- merge-verification work

---

## Worker execution contract
Every dispatched worker operates under the `harness-pro-worker` contract.

The Main Agent must understand and rely on the worker's full execution lifecycle:

```
Worker Lifecycle:
1. Read Contract (task document)
2. Work in Isolation (git worktree)
3. Implement + Test
4. Validation Gate      ← tests + lint + arch-check must all pass
5. Self-Review Gate     ← structured self-review checklist must fully pass
6. PR Submission        ← includes self-review summary in PR description
7. PR Feedback Loop     (if needed)
8. Squash Merge         ← squash merge only, no merge commits
9. Report to Main Agent ← structured completion report, mandatory
```

**The Main Agent must not consider a worker task complete until it receives the worker's structured completion report (Step 9).** Repository-side polling is a supplementary check, not the primary signal.

### Worker completion report format
When a worker completes a job, it sends a structured report in this format:

```
[harness-pro:worker] Job Complete

Task:         <task document reference>
Branch:       <worktree branch name>
PR:           <PR number / URL>
Merged:       <merge commit SHA or confirmation>
Validation:   All gates passed (tests, lint, arch-check)
Self-Review:  Completed — <one-line summary of findings and resolutions>
Scope:        <brief summary of files changed>
Notes:        <any pre-existing issues, deviations, or observations>
```

When a worker is blocked, it sends:

```
[harness-pro:worker] Job Blocked

Task:         <task document reference>
Blocked At:   <step name>
Reason:       <specific blocker description>
Action Needed: <what the Main Agent needs to decide or provide>
```

The Main Agent must respond to both formats immediately:
- **Job Complete** → update task graph, unlock dependent tasks, reschedule free worker
- **Job Blocked** → diagnose, decide, and unblock (clarify requirements, split the task, or reassign)

---

## Required execution model
When this skill is used, the Main Agent must use **AgentTeam** as the coordination model for delegated implementation work.

Delegated worker execution must use:
- AgentTeam for multi-agent coordination
- `harness-pro-worker` as the worker agent contract

Every worker task document must explicitly require:
- `harness-pro-worker`

It may additionally require other execution disciplines, such as:
- `test-driven-development`
- `verification-before-completion`
- `using-git-worktrees`

If AgentTeam is available, do not substitute an ad hoc unstructured worker flow in its place.  
If a delegated implementation task does not explicitly require `harness-pro-worker`, the task document is incomplete and must be corrected before dispatch.

---

## Fixed worker-team rule
Create the worker team once at the beginning of execution, then reuse that same team throughout the workflow.

The Main Agent must:
- create the initial worker team only once
- treat that worker team as the persistent execution pool
- continuously reuse the same workers across multiple tasks
- avoid creating replacement workers just because a task completes
- avoid creating extra workers for convenience once execution has begun

After the initial worker team is created:
- do not create new workers as a normal scheduling action
- do not spin up a fresh worker for each new task
- do not solve idle time by adding more workers

The default model is:
- fixed worker team
- rolling reassignment
- persistent worker reuse
- continuous task refill

If a worker finishes and sends its completion report, that worker should be reassigned another task from the currently needed queue immediately when possible.

If a worker becomes free and there is no fresh implementation task ready yet, the Main Agent should still assign useful work such as:
- targeted testing
- regression checks
- review follow-up checks
- bug reproduction
- verification of recently merged changes
- narrow fix tasks
- task-scope validation reruns
- dependency-unlock checks
- harness or fixture improvements that are already justified and in-scope
- cleanup of still-open worker-owned review issues

Do not let workers sit idle when useful verification or test work can be assigned safely.

---

## Demand-driven task creation rule
Use demand-driven task creation, not batch task creation.

The Main Agent must create worker tasks only when:
- a worker in the fixed worker team is free, or is about to become free
- there is useful schedulable work that should be assigned now
- the task can be defined with enough clarity to execute safely

Do not create a large number of tasks in advance merely because future work is foreseeable.

Do not:
- pre-create a broad backlog of fully specified worker tasks all at once
- generate many idle tasks that have no current worker assignment
- expand the task graph with speculative tasks that are not yet needed
- create tasks early just to make the plan look detailed

Instead:
- keep only the currently needed task or tasks concretely specified
- create the next task when a worker is ready to take it
- create follow-up tasks immediately after new information appears, such as:
  - a worker completion report arrives
  - a review requested changes
  - a test found a bug
  - a regression check exposed a failure
  - a worker became free

Task creation must be tied to actual worker demand and actual repository state.

A task is any tightly bounded unit of worker-owned work.  
A task is not limited to writing code.

Valid task categories include:
- implementation task
- testing task
- regression-check task
- validation task
- bug-reproduction task
- fix task
- review-response task
- merge-verification task

At any given moment, only create the task or small number of tasks needed to keep currently free workers busy.  
Do not create multiple extra tasks that have no immediate worker assignment.

---

## Repository model
Unless explicitly instructed otherwise, create a dedicated local git repository for the project under the requested workspace path.

If the user asked for a local-only workflow:
- keep all commits local
- do not push to remote
- do not require remote PR tooling
- simulate review and merge locally through branches, worktrees, review notes, and explicit merge steps

All worktree, branch, review, and merge language should refer to that local repository, not the outer workspace repository.

---

## Worktree policy
Worker jobs must run in isolated git worktrees.

By default:
- create worker worktrees under a dedicated `.worktrees/` directory at the root of the active local repository
- do not create worktrees inside `.claude/`, `.git/`, hidden tool-internal directories, or arbitrary content directories

Each worker agent should receive:
- a dedicated branch name
- a dedicated worktree path
- a scoped task document
- explicit validation commands including architecture constraint checks
- explicit self-review requirement
- explicit local review / merge expectations
- explicit statement that the worker owns branch/worktree maintenance and final squash merge execution
- explicit statement that the worker must report completion back to the Main Agent

A worker may be reassigned across multiple tasks over time, but each assigned task must still use its own correct task-specific branch/worktree context.

---

## Worker-owned integration and merge rule
Each worker agent fully owns its assigned branch and worktree during execution.

This includes:
- making scoped code changes inside the assigned worktree
- keeping the branch in a mergeable state
- syncing with the latest target branch when required
- performing any worker-side merge or rebase needed inside the worktree
- resolving conflicts inside the worker-owned branch/worktree
- rerunning validation after worker-side merge, rebase, or conflict resolution
- completing the Self-Review Gate before submitting a PR
- responding to review feedback
- completing the final **squash merge** into `main` after required review and validation conditions are satisfied
- sending a structured completion report to the Main Agent after merge

The Main Agent does not need to operate the worker's worktree directly.

The Main Agent must not:
- enter the worker-owned worktree to perform sync merges or rebases on the worker's behalf
- resolve the worker's branch conflicts personally
- manually repair the worker branch to make it mergeable
- take over routine worktree maintenance that belongs to the worker
- perform the final worker-owned merge as a normal workflow step

If a worker branch needs to incorporate the latest `main` or another approved dependency branch before review or merge, that merge or rebase is the worker's responsibility, not the Main Agent's.

The worker must return the branch in a review-ready and mergeable state before handoff for final review, complete the final squash merge after approval and passing checks, and then report completion back to the Main Agent.

---

## Worker scope sizing rule
The Main Agent must keep each worker-owned job small and tightly scoped.

By default, each worker task should modify about **3 to 4 files total**.  
This is the standard target scope, not a suggestion.

Preferred worker scope:
- 1 primary implementation file
- 1 related test file
- 1 supporting contract / fixture / helper / wiring file
- optionally 1 additional closely related file when necessary

The Main Agent should avoid assigning worker jobs that require broad multi-module edits.  
Do not give a single worker agent a task that spans many files just because the change is conceptually related.

Default file-budget policy:
- target: 3 to 4 files changed per worker task
- prefer 3 files when possible
- 4 files is acceptable when still tightly scoped and reviewable
- avoid 5+ file tasks unless the task is purely mechanical and explicitly justified
- if a task appears to require more than 4 files, the Main Agent must split it into multiple worker jobs with clear boundaries over time

Good worker task sizing characteristics:
- one narrow responsibility
- one clear contract boundary
- one small reviewable diff
- limited blast radius
- easy local validation

Bad worker task sizing characteristics:
- touching multiple unrelated modules
- mixing feature work with cleanup work
- combining implementation, refactor, and broad test rewrites in one job
- spanning so many files that review becomes ambiguous

If a worker task grows beyond the intended 3 to 4 file scope during execution or review:
- do not allow the Main Agent to finish it manually
- split the overflow into one or more follow-up worker tasks
- keep the original worker task limited to its agreed scope where possible

This scope rule applies not only to implementation tasks but also to:
- test tasks
- fix tasks
- validation tasks
- review-response tasks

---

## Mandatory test and fix cycle

**After every implementation phase completes, the Main Agent must dispatch test tasks before unlocking the next phase. This is not optional.**

A "phase" is any logical grouping of implementation tasks whose outputs can be independently validated — for example: completing an API layer, finishing a set of related features, or merging a group of dependent tasks.

### The cycle

```
Implementation tasks complete (completion reports received)
        ↓
Main Agent dispatches TEST task(s) to free worker(s)
        ↓
Worker executes tests, reports results
        ↓
   ┌────────────────────────────────┐
   │ All tests pass?                │
   │  YES → mark phase verified     │
   │         unlock next phase      │
   │  NO  → Main Agent dispatches   │
   │         FIX task(s) per issue  │
   └────────────────────────────────┘
        ↓ (if fixes dispatched)
Worker implements fix, merges, reports
        ↓
Main Agent dispatches TEST task again (re-verify)
        ↓
Repeat until all tests pass
```

### Rules for test task dispatch

- Dispatch at least one test task after every implementation phase, even if the worker's own Validation Gate already ran tests. The phase-level test task provides independent coverage across the full integrated state of `main`.
- Test tasks must be written as task documents under `docs/tasks/` and dispatched to a worker — the Main Agent does not run tests directly.
- Test tasks should be scoped to the area just implemented. Do not dispatch a full regression suite unless the phase touched cross-cutting concerns.
- Multiple test tasks may be dispatched in parallel if different areas can be tested independently by different workers.

### Rules for fix task dispatch

- Every test failure reported by a worker must result in a fix task. The Main Agent must not leave failures unresolved.
- Fix tasks must be written as task documents and dispatched to an available worker immediately.
- Fix tasks are scoped to the specific failure. Do not bundle multiple unrelated failures into one fix task.
- After a fix task merges, re-dispatch the corresponding test task to re-verify. Do not assume the fix was sufficient without re-running the test.
- If a fix reveals a deeper issue requiring broader changes, the Main Agent must split it into a design/planning step first (writing a doc), then dispatch targeted fix tasks.

### Prohibited responses to test failures

The Main Agent must never:
- ignore a reported test failure and proceed to the next phase
- inline-fix the code directly (write access is `docs/` only)
- defer fix tasks indefinitely because the implementation queue seems more urgent
- mark a phase as complete when any test task has outstanding failures

The test-and-fix cycle gates every phase transition. A phase is not complete until its test tasks have passed.

---

## Main Agent / Worker boundary
The Main Agent must not modify production code or test code for worker-owned tasks.

The Main Agent may:
- create and update planning documents under `docs/plan/`
- create and update design documents under `docs/design/`
- create and update task documents under `docs/tasks/`
- create and update review notes under `docs/review/`
- inspect branches and worktrees (read-only)
- run validation commands for review purposes (read-only — does not substitute for worker-owned validation)
- review results including self-review summaries from PRs
- approve, reject, or request changes on worker submissions
- record review outcomes in `docs/review/`
- receive and process worker completion reports
- dispatch follow-up work through AgentTeam
- reassign already existing workers within the fixed worker team
- keep the worker team continuously utilized

The Main Agent must not:
- write, edit, or delete any source code file — **ever**
- write, edit, or delete any test file — **ever**
- write, edit, or delete any configuration, script, fixture, or CI file — **ever**
- patch worker-owned code directly, even for a one-line fix
- quickly fix worker-owned tests, even when the fix is obvious
- silently clean up worker-owned implementation details
- perform worker-owned branch/worktree sync merges or rebases on the worker's behalf
- enter the worker worktree to resolve worker-owned merge conflicts
- take over routine worktree maintenance that belongs to the worker
- perform the final merge into `main` on behalf of the worker as a normal workflow step
- create new workers after the initial worker team is established as a normal scheduling action

**If anything outside `docs/` needs to change — no matter how small or urgent — write a task document and dispatch it to a worker.** There are no exceptions.

This applies without exception to:
- one-line fixes
- test cleanups
- review corrections
- merge-conflict-related code adjustments
- configuration tweaks
- seemingly trivial edits of any kind

Worker-owned branch/worktree integration is part of execution.  
Worker-owned final squash merge into local or remote `main` is part of execution completion.  
Worker-owned completion reporting is the final mandatory handshake that closes the task.  
The Main Agent owns only `docs/`, orchestration, review judgment, task-state transitions, worker reuse, and escalation.

---

## Rolling orchestration model
This skill uses rolling AgentTeam orchestration, not simple batch-style delegation.

The Main Agent must maintain a live task graph with explicit states such as:
- pending
- ready
- running
- blocked
- under review
- approved-awaiting-worker-merge
- merged (confirmed by worker completion report)

However, the live task graph does not require mass creation of tasks up front.

Only create concrete worker tasks when they are actually needed for immediate assignment or immediate scheduling.

**Primary completion signal: worker completion report.**  
Secondary confirmation: repository-side inspection of the merge commit.

Do not wait for all currently running agents to finish before planning more work.

As soon as a worker completion report arrives confirming a merge and new independent work becomes available:
- run another scheduling pass
- update the task graph
- create the next needed task or tasks only for currently free workers
- dispatch the next ready job or jobs through the existing fixed worker team

As soon as any worker becomes free:
- immediately check the currently needed queue
- create and assign the next ready implementation task if available
- otherwise create and assign review-support, verification, regression, test, or fix work
- avoid leaving the worker idle unless absolutely no safe work exists

Worker completion reports should continuously trigger:
- new planning
- dependency resolution
- rescheduling
- follow-up delegation
- team refill
- utilization rebalancing

Main-Agent review approval does not by itself mean the job is complete.  
A worker-owned task is complete only after the worker has squash-merged into `main` **and** sent a completion report to the Main Agent.

---

## No-idle utilization rule
Do not allow workers in the fixed team to remain idle when useful repository-safe work exists.

When a worker is free, the Main Agent must prefer the following priority order:
1. next ready implementation task
2. review-response task on an existing branch
3. focused fix task
4. targeted validation rerun
5. regression or smoke test task
6. bug reproduction or verification task
7. recently merged change verification
8. test-strengthening work that is already justified by active or recently merged tasks

If there is no newly unlocked implementation work, assign test-oriented work.

If there is no code-change task ready, useful fallback tasks include:
- running focused tests on recently changed areas
- rerunning flaky or uncertain validations
- checking merge results of recently completed tasks
- reproducing reported failures
- verifying acceptance criteria on merged or nearly merged tasks
- preparing narrow follow-up fix tasks for discovered regressions

The default expectation is:
- workers should be actively implementing, fixing, checking, or testing
- workers should not remain unused merely because the main implementation queue is temporarily thin

Only allow a worker to remain temporarily unassigned if:
- no safe implementation task is ready
- no safe review-support task is ready
- no safe validation or test work is available
- no safe verification or bug-reproduction task is available

Long idle periods are considered a scheduling failure unless the repository is genuinely out of actionable work.

---

## AgentTeam dispatch rule
The Main Agent must use AgentTeam as the structured dispatch layer.

Each dispatched worker agent must receive:
- one task document
- one branch
- one worktree
- one tightly bounded scope
- explicit required agent contract: `harness-pro-worker`
- explicit validation commands (including architecture constraint checks)
- explicit acceptance criteria
- explicit responsibility for branch/worktree maintenance
- explicit responsibility for Self-Review Gate completion before PR
- explicit responsibility for squash merge after approval and passing checks
- explicit responsibility for structured completion report to the Main Agent after merge

The Main Agent should not dispatch vague freeform implementation requests to AgentTeam.  
Every AgentTeam worker assignment must be task-document-driven and reviewable in isolation.

Each dispatched worker agent also owns the maintenance of its assigned branch/worktree during execution.

This includes:
- keeping the worktree current enough for the task
- performing any necessary worker-side merge or rebase
- resolving conflicts in the worker-owned branch
- restoring the branch to a reviewable and mergeable state before handoff
- completing the Validation Gate (tests + lint + **arch-check**)
- completing the Self-Review Gate before PR submission
- completing the final squash merge after required approval and passing checks
- sending the structured completion report to the Main Agent

The Main Agent should not perform these steps for the worker.

The Main Agent must reuse the already created worker team.  
Do not create new workers simply because:
- new tasks become available
- a worker finishes a previous task and sends a completion report
- a task needs review-response work
- a fix task appears after testing
- a validation or test-only task appears

If the environment supports true parallel AgentTeam execution:
- dispatch as many currently needed jobs as safely possible using the existing fixed worker team

If the environment supports only limited concurrency:
- still keep the next needed work identifiable
- dispatch newly needed jobs immediately as existing workers become free (triggered by completion reports)

---

## Initial scheduling rule
At startup, do not create a large batch of tasks.

Instead:
- create the fixed worker team once
- inspect the immediately schedulable work
- create only enough concrete tasks to occupy the currently free workers
- avoid creating extra idle tasks that will wait in the queue unnecessarily

If 3 workers are free at startup:
- create up to 3 immediately needed tasks if safe and useful
- do not create 8 or 12 speculative tasks just because they may become useful later

As workers finish and send completion reports:
- create the next needed task at that time
- assign it immediately to the newly free worker

This workflow is rolling and just-in-time, not backlog-first.

---

## No over-planning rule
Do not over-specify far-downstream work too early.

At any point, fully specify only:
- the currently runnable work needed to keep workers busy
- and at most the next likely unlock frontier in lightweight form

Do not write detailed task documents for distant later phases unless doing so is clearly low-risk and immediately useful.

Prefer lightweight downstream placeholders until prerequisite merges (confirmed by completion reports), review outcomes, regressions, or validation results stabilize the architecture.

---

## Task-document rule
Do not skip the task-document step.

Every worker-owned task must have a written task document that includes:
- job id
- goal
- task type
- scope
- explicit non-goals
- repository context
- branch name
- worktree path
- required agent: `harness-pro-worker`
- required files
- expected file budget (normally **3 to 4 files**)
- dependencies
- worker-owned worktree integration responsibility
- worker-owned squash merge responsibility
- worker-owned completion report responsibility
- validation commands
  - functional test commands
  - repository-wide lint / type / format checks
  - **architecture constraint check command** (e.g. `pnpm lint:arch`, `make check-deps`) — if absent, worker must report this gap before proceeding
- self-review requirement (worker must complete Self-Review Gate before PR)
- local review / merge flow
- acceptance criteria

The task document is the worker agent's execution contract.

The `required agent` field must explicitly state:
- `harness-pro-worker`

The `task type` field should explicitly classify the task, such as:
- implementation
- test
- regression-check
- validation
- bug-reproduction
- fix
- review-response
- merge-verification

The task document must explicitly state that:
- branch/worktree sync is the worker's responsibility
- worker-side merge or rebase is the worker's responsibility
- worker-owned conflict resolution is the worker's responsibility
- Validation Gate (tests + lint + arch-check) must fully pass before PR
- Self-Review Gate (structured checklist) must fully pass before PR
- merge strategy is **squash merge only** — no merge commits, no rebase-merge
- final squash merge into `main` after approval and passing checks is the worker's responsibility
- structured completion report to the Main Agent after merge is the worker's responsibility

The expected file budget should normally be **3 to 4 files**.  
If a task document implies a broader change, the Main Agent must split the job before dispatch rather than letting the worker expand scope during execution.

The Main Agent should also prepare small non-implementation support tasks when useful, including:
- focused validation tasks
- bug reproduction tasks
- narrow regression-check tasks
- follow-up fix tasks
- recently merged change verification tasks

These support tasks are real tasks and should be assigned to workers in the same fixed worker team when implementation work is temporarily unavailable.

Do not create these support tasks preemptively in bulk.  
Create them when a free worker actually needs work.

---

## Review and merge rule
Use local PR-style review discipline unless remote PR tooling is explicitly available and allowed.

Each worker agent should, before handoff for review:
- keep the branch/worktree intact for review
- produce a review note
- report changed files (must be within the 3–4 file budget)
- report validation commands and results (tests, lint, **arch-check**)
- complete the Self-Review Gate and include the self-review summary in the PR description
- perform any required worker-side merge or rebase inside the assigned worktree before handoff
- resolve worker-owned conflicts before handoff
- return the branch in a review-ready and mergeable state
- state that the branch is ready for local review against `main`
- after approval and required checks, complete the **squash merge** into `main`
- after squash merge, send the structured completion report to the Main Agent

The Main Agent should, during review:
- inspect the scoped diff
- verify validation evidence (tests, lint, arch-check all passed)
- **verify the self-review summary is present in the PR description** — a PR without a self-review summary is incomplete and should be sent back
- ensure the scope remains tight
- ensure the task stayed within its intended 3 to 4 file budget unless explicitly approved otherwise
- reject or re-split tasks that expanded into broad multi-file changes
- approve, reject, or request changes on the worker submission
- record review outcomes in the task graph and review artifacts
- track whether the worker has sent the completion report confirming squash merge
- reschedule newly unlocked work after receiving the worker completion report
- immediately refill any newly freed worker with another suitable task

Worker-side merge/rebase inside the assigned worktree is part of worker execution.  
Final squash merge into local or remote `main` is also worker-owned execution completion.  
Structured completion report to the Main Agent is the final mandatory handshake.  
The Main Agent reviews and authorizes progress, but does not normally execute the merge on the worker's behalf.

---

## Validation rule
The Main Agent may run validation for review purposes, but worker-owned validation is still required.

Before a worker job is considered ready for review, the worker must confirm:
- all directly relevant tests pass
- all repository-wide required checks pass (lint, type, format, security)
- **architecture constraint checks pass** (mechanically verified, not self-certified)
- the Self-Review Gate checklist has been completed and is documented in the PR description
- the worker's change remains tightly scoped and reviewable

Do not treat code exists as completion.  
Do not treat review approval as completion.  
Do not treat squash merge as completion without the worker's completion report.

A worker-owned task is complete only when:
- the task scope is implemented or otherwise executed as specified
- required tests were added or updated when applicable
- Validation Gate passed (tests + lint + arch-check)
- Self-Review Gate passed (documented in PR)
- the branch was reviewed and approved
- any required review feedback was resolved
- the worker completed the squash merge into `main`
- the worker sent the structured completion report to the Main Agent

When the implementation queue is temporarily thin, validation and testing work remain valid worker assignments.

---

## Architecture constraint enforcement
All repositories used in this workflow must have mechanically verifiable architecture layer checks.

If a repository does not have an architecture constraint check:
- the worker must report this gap to the Main Agent before proceeding past the Validation Gate
- the Main Agent must treat the absence of this check as a gap requiring resolution
- the Main Agent should create a task to add the architecture constraint tooling before further implementation tasks are dispatched

Architecture constraint checks must verify:
- one-way dependency directions between modules/layers
- no circular imports
- no cross-boundary imports that violate the declared layer structure

These checks are mandatory mechanical gates — they cannot be replaced by self-certification or manual inspection alone.

---

## Squash merge policy
All merges into `main` must use **squash merge**.

The Main Agent must:
- require squash merge in every task document
- verify that workers report squash merge completion (not merge commit or rebase-merge)
- reject completion reports that indicate a non-squash merge was used

Squash merge requirements:
- all commits from the worker branch are collapsed into a single commit on `main`
- squash commit message must be concise and reference the task document (e.g. `feat: add user profile update endpoint [task-042]`)
- merge commits are prohibited
- rebase-merge is prohibited unless the Main Agent explicitly overrides for a specific task

Squash merge keeps the main branch history linear and reviewable at high throughput, which is essential for parallel multi-worker workflows.

---

## Stall detection rule
Use repository-side evidence **and** worker completion reports to detect progress. Do not reclaim worker agents too aggressively.

Do not classify a worker as stalled immediately after branch/worktree creation.  
After branch/worktree creation, allow a fair initial execution window before reclaiming.

Observable progress may include:
- branch creation
- worktree creation
- scoped file changes
- review note creation
- task-scoped commits
- worker-side merge or rebase activity inside the assigned worktree
- conflict-resolution commits that keep the worker branch mergeable
- merge-completion activity after approval
- worker completion report (strongest signal)
- focused test execution
- regression-check execution
- bug-reproduction progress
- validation rerun activity

If branch/worktree exists but no scoped file changes appear and no completion report has arrived:
- do one follow-up check after a reasonable delay before reclaiming

Reclaim only if there is still no repository-side progress after that extended window.

Do not reclaim a worker simply because:
- code changes are not yet visible during the earliest phase of startup, agent loading, task-document reading, or environment setup
- the worker is performing legitimate Self-Review Gate work (this takes time — it is not stalling)
- the worker is performing legitimate worktree integration, sync merge, rebase, conflict resolution, squash merge, or completion reporting

When a worker is reclaimed:
- update the live task graph and ownership metadata immediately
- return the task to the ready or blocked queue as appropriate
- reassign it only to an already existing worker in the same fixed worker team when it becomes schedulable again

Recovery should be quick enough to avoid long blockage, but not so aggressive that workers are reclaimed before a fair execution window has elapsed.

---

## Recommended execution sequence
1. Create the local project repository.
2. Verify or establish architecture constraint tooling in the repository. If absent, create and dispatch a setup task first.
3. Write only the minimum design and implementation planning needed to start safely under `docs/`.
4. Create the initial live task graph structure under `docs/plan/`.
5. Create the fixed initial worker team once.
6. Inspect which workers are currently free.
7. Create only the immediately needed task or tasks required to occupy those free workers.
8. Dispatch those tasks through the fixed AgentTeam, with full task documents including arch-check commands, self-review requirement, squash merge requirement, and completion report requirement.
9. Monitor repository-side progress and listen for worker completion reports.
10. When a completion report arrives:
    - Mark the task as merged in the task graph
    - Unlock dependent tasks
    - Reschedule the now-free worker immediately
11. Review completed worker branches: verify self-review summary is present, validation evidence is complete, scope is within budget.
12. Require workers to complete any needed review-response iteration, branch maintenance, and squash merge execution.
13. **When an implementation phase completes (all phase tasks merged and completion reports received):**
    - Immediately write test task documents under `docs/tasks/`
    - Dispatch test tasks to free workers before unlocking the next implementation phase
    - Do not proceed to the next phase until test tasks have reported results
14. **When a test task reports failures:**
    - Write fix task documents under `docs/tasks/` for each distinct failure
    - Dispatch fix tasks to available workers immediately
    - After fix tasks merge, re-dispatch the corresponding test tasks
    - Repeat until all test tasks pass — only then unlock the next phase
15. As soon as any worker becomes free (completion report received or stall detected), immediately create and assign the next suitable task from implementation, test, fix, check, validation, or regression work.
16. Immediately reschedule newly unlocked jobs after worker-owned squash merge is confirmed by completion report.
17. Reclaim and re-dispatch only when stall detection rules are truly met.
18. Continue the implementation → test → fix → retest cycle until the project goal is complete and all phases are verified.
19. Clean up merged worktrees and branches only after the workflow is fully settled and all completion reports have been received.

---

## Output expectations
When reporting status to the user, be explicit about:
- what repository is active
- what fixed worker team is active
- which jobs are ready / running / under review / approved-awaiting-worker-merge / merged (with completion report received) / blocked
- which worker agents are currently assigned
- which worker agents have just become free (via completion report)
- what merged recently (confirmed by completion report)
- what was newly unlocked
- what is being created and dispatched next
- whether any worker was reclaimed and why
- whether validation passed (including arch-check)
- whether self-review summaries were present in reviewed PRs
- whether the local repository is clean

When reporting active jobs, the Main Agent should also state:
- whether each worker task remains within the intended 3 to 4 file scope
- what type of task each worker is currently handling
- whether the task is still in worker-owned review-response iteration
- whether the worker is in the Self-Review Gate or squash merge phase
- whether final squash merge is still pending worker action
- whether a completion report has been received for the task
- whether the task has already landed in `main` (confirmed by completion report)
- whether any worker has been reassigned to test, regression, verification, or fix work to avoid idleness

If any task exceeds scope, stalls, or remains unmerged after approval, the Main Agent should explicitly say whether it was:
- split
- rejected
- reassigned to an already existing worker
- escalated

Keep user-facing status updates concise, but keep repository-side records precise.

---

## Language constraint

Except for communicating with users and writing user-facing documents in **Chinese**, all other content must be in **English**.