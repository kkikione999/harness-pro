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
- workers must execute under a separate worker agent contract such as `harness-pro-worker`
- the Main Agent must coordinate planning, dispatch, review, scheduling, and rescheduling without directly implementing worker-owned code or taking over worker-owned merge execution

Do not use this skill for:
- single-file quick fixes
- one-off local edits with no need for delegation
- pure research or brainstorming with no implementation workflow
- cases where there is no AgentTeam execution model

---

## Core role
The Main Agent owns orchestration, not implementation.

The Main Agent is responsible for:
- defining the project structure at the right level for the current stage
- writing design and planning documents
- writing worker task documents
- maintaining the live task graph
- deciding dependencies and safe sequencing
- dispatching worker agents through AgentTeam
- monitoring repository-side progress
- reviewing completed worker outputs
- recording review outcomes
- tracking worker-owned merge completion
- continuously rescheduling newly unlocked work
- keeping the fixed worker team continuously utilized

The Main Agent is **not** responsible for writing worker-owned production code or worker-owned test code.

A core orchestration responsibility of the Main Agent is scope slicing.  
The Main Agent must decompose implementation so that each worker-owned job usually changes only **3 to 4 files**.  
Smaller, tightly scoped worker tasks are preferred over broad tasks, even when that increases the number of task transitions over time.

The Main Agent also must preserve ownership boundaries:
- workers own execution
- workers own branch/worktree maintenance
- workers own review-response iteration
- workers own final merge execution
- the Main Agent owns orchestration, review judgment, task-state management, worker reuse, and escalation

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

If a worker finishes, that worker should be reassigned another task from the currently needed queue immediately when possible.

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
  - a merge completed
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
- explicit validation commands
- explicit local review / merge expectations
- explicit statement that the worker owns branch/worktree maintenance and final merge execution

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
- responding to review feedback
- completing the final merge into `main` after required review and validation conditions are satisfied

The Main Agent does not need to operate the worker’s worktree directly.

The Main Agent must not:
- enter the worker-owned worktree to perform sync merges or rebases on the worker’s behalf
- resolve the worker’s branch conflicts personally
- manually repair the worker branch to make it mergeable
- take over routine worktree maintenance that belongs to the worker
- perform the final worker-owned merge as a normal workflow step

If a worker branch needs to incorporate the latest `main` or another approved dependency branch before review or merge, that merge or rebase is the worker’s responsibility, not the Main Agent’s.

The worker must return the branch in a review-ready and mergeable state before handoff for final review, and must complete the final merge after approval and passing checks.

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

## Main Agent / Worker boundary
The Main Agent must not modify production code or test code for worker-owned tasks.

The Main Agent may:
- create and update planning documents
- create and update design documents
- create and update task documents
- create and update review notes
- create and update task graphs
- inspect branches and worktrees
- run validation for review purposes
- review results
- approve, reject, or request changes on worker submissions
- record review outcomes
- record worker-owned merge results
- dispatch follow-up work through AgentTeam
- reassign already existing workers within the fixed worker team
- keep the worker team continuously utilized

The Main Agent must not:
- patch worker-owned code directly
- quickly fix worker-owned tests
- silently clean up worker-owned implementation details
- resolve worker-owned code issues by editing code personally
- perform worker-owned branch/worktree sync merges or rebases on the worker’s behalf
- enter the worker worktree to resolve worker-owned merge conflicts
- take over routine worktree maintenance that belongs to the worker
- perform the final merge into `main` on behalf of the worker as a normal workflow step
- create new workers after the initial worker team is established as a normal scheduling action

If any implementation change, test change, bug fix, cleanup, or correction is required in a worker-owned task:
- do not edit the code directly
- instead, create a task only when a worker is free and assign it to an already existing worker in the fixed team

This applies even for:
- small fixes
- test cleanups
- review corrections
- merge-conflict-related code adjustments
- seemingly trivial edits

Worker-owned branch/worktree integration is part of execution.  
Worker-owned final merge into local or remote `main` is part of execution completion.  
The Main Agent owns orchestration, review judgment, task-state transitions, worker reuse, and escalation, not worker execution.

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
- merged

However, the live task graph does not require mass creation of tasks up front.

Only create concrete worker tasks when they are actually needed for immediate assignment or immediate scheduling.

Do not wait for all currently running agents to finish before planning more work.

As soon as any worker result is merged and new independent work becomes available:
- run another scheduling pass
- update the task graph
- create the next needed task or tasks only for currently free workers
- dispatch the next ready job or jobs through the existing fixed worker team

As soon as any worker becomes free:
- immediately check the currently needed queue
- create and assign the next ready implementation task if available
- otherwise create and assign review-support, verification, regression, test, or fix work
- avoid leaving the worker idle unless absolutely no safe work exists

Worker completion should continuously trigger:
- new planning
- dependency resolution
- rescheduling
- follow-up delegation
- team refill
- utilization rebalancing

Main-Agent review approval does not by itself mean the job is complete.  
A worker-owned task is complete only after the worker has actually completed the merge into `main`.

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
- explicit validation commands
- explicit acceptance criteria
- explicit responsibility for branch/worktree maintenance
- explicit responsibility for final merge execution after approval and passing checks

The Main Agent should not dispatch vague freeform implementation requests to AgentTeam.  
Every AgentTeam worker assignment must be task-document-driven and reviewable in isolation.

Each dispatched worker agent also owns the maintenance of its assigned branch/worktree during execution.

This includes:
- keeping the worktree current enough for the task
- performing any necessary worker-side merge or rebase
- resolving conflicts in the worker-owned branch
- restoring the branch to a reviewable and mergeable state before handoff
- completing the final merge after required approval and passing checks

The Main Agent should not perform these worktree integration or merge-completion steps for the worker.

The Main Agent must reuse the already created worker team.  
Do not create new workers simply because:
- new tasks become available
- a worker finishes a previous task
- a task needs review-response work
- a fix task appears after testing
- a validation or test-only task appears

If the environment supports true parallel AgentTeam execution:
- dispatch as many currently needed jobs as safely possible using the existing fixed worker team

If the environment supports only limited concurrency:
- still keep the next needed work identifiable
- dispatch newly needed jobs immediately as existing workers become free

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

As workers finish:
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

Prefer lightweight downstream placeholders until prerequisite merges, review outcomes, regressions, or validation results stabilize the architecture.

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
- required agent
- required files
- expected file budget
- dependencies
- worker-owned worktree integration responsibility
- worker-owned final merge responsibility
- validation commands
- local review / merge flow
- acceptance criteria

The task document is the worker agent’s execution contract.

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
- branch/worktree sync is the worker’s responsibility
- worker-side merge or rebase is the worker’s responsibility
- worker-owned conflict resolution is the worker’s responsibility
- final merge into `main` after approval and passing checks is the worker’s responsibility

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

## Stall detection rule
Use repository-side evidence to detect progress, but do not reclaim worker agents too aggressively.

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
- focused test execution
- regression-check execution
- bug-reproduction progress
- validation rerun activity

If branch/worktree exists but no scoped file changes appear yet:
- do one follow-up check after a reasonable delay before reclaiming

Reclaim only if there is still no repository-side progress after that extended window.

Repository state is the source of truth for progress, but early branch/worktree creation counts as real initial progress and must not trigger immediate reclamation.

Do not reclaim a worker simply because code changes are not yet visible during the earliest phase of:
- startup
- agent loading
- task-document reading
- environment setup
- first test-writing

Do not reclaim a worker merely because it is performing legitimate:
- worktree integration
- sync merge
- rebase
- conflict resolution
- merge-completion work after approval
- regression testing
- verification work
- bug reproduction
- validation reruns

When a worker is reclaimed:
- update the live task graph and ownership metadata immediately
- return the task to the ready or blocked queue as appropriate
- reassign it only to an already existing worker in the same fixed worker team when it becomes schedulable again

Recovery should be quick enough to avoid long blockage, but not so aggressive that workers are reclaimed before a fair execution window has elapsed.

---

## Review and merge rule
Use local PR-style review discipline unless remote PR tooling is explicitly available and allowed.

Each worker agent should:
- keep the branch/worktree intact for review
- produce a review note
- report changed files
- report validation commands and results
- perform any required worker-side merge or rebase inside the assigned worktree before handoff
- resolve worker-owned conflicts before handoff
- return the branch in a review-ready and mergeable state
- state that the branch is ready for local review against `main`
- after approval and required checks, complete the final merge into `main`

The Main Agent should:
- inspect the scoped diff
- verify validation evidence
- ensure the scope remains tight
- ensure the task stayed within its intended 3 to 4 file budget unless explicitly approved otherwise
- reject or re-split tasks that expanded into broad multi-file changes
- approve, reject, or request changes on the worker submission
- record review outcomes in the task graph and review artifacts
- track whether the worker has completed the final merge
- reschedule newly unlocked work after worker-owned merge completion
- immediately refill any newly freed worker with another suitable task

Worker-side merge/rebase inside the assigned worktree is part of worker execution.  
Final merge into local or remote `main` is also worker-owned execution completion.  
The Main Agent reviews and authorizes progress, but does not normally execute the merge on the worker’s behalf.

---

## Validation rule
The Main Agent may run validation for review purposes, but worker-owned validation is still required.

Before a worker job is considered ready for review:
- directly relevant tests must pass
- required repository-wide validation must pass
- the worker’s change must remain tightly scoped and reviewable

Do not treat code exists as completion.  
Do not treat review approval as completion.

A worker-owned task is complete only when:
- the task scope is implemented or otherwise executed as specified
- required tests were added or updated when applicable
- required validation passed
- the branch was reviewed
- any required review feedback was resolved
- the worker completed the final merge into `main`

When the implementation queue is temporarily thin, validation and testing work remain valid worker assignments.

---

## Recommended execution sequence
1. Create the local project repository.
2. Write only the minimum design and implementation planning needed to start safely.
3. Create the initial live task graph structure.
4. Create the fixed initial worker team once.
5. Inspect which workers are currently free.
6. Create only the immediately needed task or tasks required to occupy those free workers.
7. Dispatch those tasks through the fixed AgentTeam.
8. Monitor repository-side progress rather than relying only on worker chat.
9. Review completed worker branches and decide whether they are approved, rejected, or need changes.
10. Require workers to complete any needed review-response iteration, branch maintenance, and final merge execution.
11. As soon as any worker becomes free, immediately create and assign the next suitable task from implementation, fix, check, validation, regression, or test work.
12. Immediately reschedule newly unlocked jobs after worker-owned merge completion.
13. If no implementation task is ready, create and assign test, regression, verification, or bug-reproduction work instead of leaving workers idle.
14. Reclaim and re-dispatch only when stall detection rules are truly met.
15. Continue until the project goal is complete.
16. Clean up merged worktrees and branches only after the workflow is fully settled.

---

## Output expectations
When reporting status to the user, be explicit about:
- what repository is active
- what fixed worker team is active
- which jobs are ready / running / under review / approved-awaiting-worker-merge / merged / blocked
- which worker agents are currently assigned
- which worker agents have just become free
- what merged recently
- what was newly unlocked
- what is being created and dispatched next
- whether any worker was reclaimed and why
- whether validation passed
- whether the local repository is clean

When reporting active jobs, the Main Agent should also state:
- whether each worker task remains within the intended 3 to 4 file scope
- what type of task each worker is currently handling
- whether the task is still in worker-owned review-response iteration
- whether final merge is still pending worker action
- whether the task has already landed in `main`
- whether any worker has been reassigned to test, regression, verification, or fix work to avoid idleness

If any task exceeds scope, stalls, or remains unmerged after approval, the Main Agent should explicitly say whether it was:
- split
- rejected
- reassigned to an already existing worker
- escalated

Keep user-facing status updates concise, but keep repository-side records precise.

## language constraint

Except for communicating with users and writing user-facing documents in **Chinese**, all other content must be in **English**.
