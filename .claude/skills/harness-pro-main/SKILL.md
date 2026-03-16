---
name: harness-pro-main
description: Main-agent orchestration skill for large multi-step engineering projects in Claude. Use this skill when the task requires AgentTeam-based multi-agent execution, task-document-driven worker dispatch, strict Main Agent/Worker separation, small-scope worker jobs, isolated local git worktrees, and continuous rolling rescheduling as worker jobs merge.
---

# harness-pro-main

## Purpose
`harness-pro-main` is a Main Agent orchestration skill for large, multi-step engineering workflows in Claude.

Use this skill when:
- the task is too large for a single agent
- work should be decomposed into many small worker-owned jobs
- AgentTeam should be used for coordinated multi-agent execution
- isolated git worktrees should be used
- workers must execute under a separate worker agent contract such as `harness-pro-worker`
- the Main Agent must coordinate planning, dispatch, review, merge, and rescheduling without directly implementing worker-owned code

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
- deciding dependencies and safe parallelism
- dispatching worker agents through AgentTeam
- monitoring repository-side progress
- reviewing completed worker outputs
- merging approved worker branches
- rescheduling newly unlocked work

The Main Agent is **not** responsible for writing worker-owned production code or worker-owned test code.

A core orchestration responsibility of the Main Agent is scope slicing.  
The Main Agent must decompose implementation so that each worker-owned job usually changes only **3 to 4 files**.  
Smaller, tightly scoped worker tasks are preferred over broad tasks, even when that increases the number of jobs in the task graph.

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
- local review / merge expectations

---

## Worker scope sizing rule
The Main Agent must keep each worker-owned implementation job small and tightly scoped.

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
- if a task appears to require more than 4 files, the Main Agent must split it into multiple worker jobs with clear dependencies

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

---

## Main Agent / Worker boundary
The Main Agent must not modify production code or test code for worker-owned implementation tasks.

The Main Agent may:
- create and update planning documents
- create and update design documents
- create and update task documents
- create and update review notes
- create and update task graphs
- inspect branches and worktrees
- run validation for review purposes
- review results
- merge approved work
- dispatch follow-up work through AgentTeam

The Main Agent must not:
- patch worker-owned code directly
- quickly fix worker-owned tests
- silently clean up worker-owned implementation details
- resolve worker-owned code issues by editing code personally

If any implementation change, test change, bug fix, cleanup, or correction is required in a worker-owned task:
- do not edit the code directly
- instead, create a new worker task or re-dispatch the existing task to a worker agent

This applies even for:
- small fixes
- test cleanups
- review corrections
- merge-conflict-related code adjustments
- seemingly trivial edits

---

## Rolling orchestration model
This skill uses rolling AgentTeam orchestration, not simple batch-style delegation.

The Main Agent must maintain a live task graph with explicit states such as:
- pending
- ready
- running
- blocked
- under review
- merged

Do not wait for all currently running agents to finish before planning more work.

As soon as any worker result is merged and new independent work becomes available:
- run another scheduling pass
- update the task graph
- dispatch the next ready job or jobs through AgentTeam

Worker completion should continuously trigger:
- new planning
- dependency resolution
- rescheduling
- follow-up delegation

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

The Main Agent should not dispatch vague freeform implementation requests to AgentTeam.  
Every AgentTeam worker assignment must be task-document-driven and reviewable in isolation.

If the environment supports true parallel AgentTeam execution:
- dispatch as many ready jobs as safely possible

If the environment supports only limited concurrency:
- still maintain a broad ready queue
- dispatch newly ready jobs immediately as slots free up

---

## High-concurrency opening rule
After the absolute minimum repository baseline is created, the Main Agent should design the initial architecture and contracts so that the first true implementation wave contains at least **6 independent worker-owned jobs** whenever the task realistically supports that level of parallelism.

Those initial jobs must be:
- genuinely parallel-safe
- scoped to distinct files, modules, or contracts
- small enough that each worker typically changes only 3 to 4 files
- reviewable in isolation
- not merely parallel on paper

If the environment cannot run that many worker agents at once:
- still keep at least 6 jobs in the ready queue when realistic
- dispatch new jobs immediately as slots free up

To enable this, stabilize shared contracts early enough to unlock broad safe parallelism.

Good first-wave job types often include:
- package / build / CLI scaffold
- diagnostics primitives
- source spans
- token definitions
- AST core
- backend IR or bytecode contract
- test harness and fixtures

When designing the first wave, the Main Agent should prefer a larger number of narrowly scoped worker jobs over a smaller number of broad jobs.  
Safe parallelism should be achieved by stabilizing interfaces early, then slicing work into 3 to 4 file worker tasks.  
Do not unlock concurrency by giving a single worker a wide multi-file implementation bundle.

---

## No over-planning rule
Do not over-specify far-downstream work too early.

At any point, fully specify only:
- the current runnable wave
- and at most the next unlock frontier

Do not write detailed task documents for distant later phases unless doing so is clearly low-risk and does not freeze assumptions too early.

Prefer lightweight downstream placeholders until prerequisite merges stabilize the architecture.

---

## Task-document rule
Do not skip the task-document step.

Every worker-owned implementation job must have a written task document that includes:
- job id
- goal
- scope
- explicit non-goals
- repository context
- branch name
- worktree path
- required agent
- required files
- expected file budget
- dependencies
- validation commands
- local review / merge flow
- acceptance criteria

The task document is the worker agent’s execution contract.

The `required agent` field must explicitly state:
- `harness-pro-worker`

The expected file budget should normally be **3 to 4 files**.  
If a task document implies a broader change, the Main Agent must split the job before dispatch rather than letting the worker expand scope during execution.

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

When a worker is reclaimed:
- update the live task graph and ownership metadata immediately
- re-dispatch to a fresh AgentTeam worker if the task is still ready

Recovery should be quick enough to avoid long blockage, but not so aggressive that workers are reclaimed before a fair execution window has elapsed.

---

## Review and merge rule
Use local PR-style review discipline unless remote PR tooling is explicitly available and allowed.

Each worker agent should:
- keep the branch/worktree intact for review
- produce a review note
- report changed files
- report validation commands and results
- state that the branch is ready for local review against `main`

The Main Agent should:
- inspect the scoped diff
- verify validation evidence
- ensure the scope remains tight
- ensure the task stayed within its intended 3 to 4 file budget unless explicitly approved otherwise
- reject or re-split tasks that expanded into broad multi-file changes
- merge approved work into local `main`
- record merge results in the task graph and review artifacts

---

## Validation rule
The Main Agent may run validation for review purposes, but worker-owned validation is still required.

Before a worker job is considered ready for merge:
- directly relevant tests must pass
- required repository-wide validation must pass
- the worker’s change must remain tightly scoped and reviewable

Do not treat code exists as completion.

A worker-owned implementation job is complete only when:
- the task scope is implemented
- required tests were added or updated
- required validation passed
- the branch was reviewed
- the change was merged into local `main`

---

## Recommended execution sequence
1. Create the local project repository.
2. Write only the minimum design and implementation planning needed to unlock the first wave safely.
3. Create the initial live task graph.
4. Write the first runnable wave of worker task documents.
5. Write at most the next unlock frontier.
6. Dispatch the first worker wave through AgentTeam.
7. Monitor repository-side progress rather than relying only on worker chat.
8. Review and merge completed worker branches.
9. Immediately reschedule newly unlocked jobs.
10. Reclaim and re-dispatch only when stall detection rules are truly met.
11. Continue until the project goal is complete.
12. Clean up merged worktrees and branches only after the workflow is fully settled.

---

## Output expectations
When reporting status to the user, be explicit about:
- what repository is active
- which jobs are ready / running / merged / blocked
- which worker agents are active
- what merged recently
- what was newly unlocked
- what is being dispatched next
- whether any worker was reclaimed and why
- whether validation passed
- whether the local repository is clean

When reporting active jobs, the Main Agent should also state whether each worker task remains within the intended 3 to 4 file scope.  
If any task exceeds that scope, the Main Agent should explicitly say whether it was split, rejected, or re-dispatched.

Keep user-facing status updates concise, but keep repository-side records precise.