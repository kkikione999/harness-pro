---
name: harness-pro-worker
description: Execution-focused worker workflow for small, clearly scoped engineering jobs in a multi-agent workflow. Use this skill only after a Main Agent has already defined a concrete task, split it into a small executable job, and documented the requirements, scope boundaries, references, constraints, and acceptance criteria. This skill is for disciplined implementation, testing, review response, branch/worktree maintenance, PR or local-review submission, and merge completion in an isolated git worktree.
---

# harness-pro-worker

## Purpose

`harness-pro-worker` is an execution-focused worker skill for small, clearly scoped engineering jobs in a multi-agent workflow.

Use this skill only when:
- a Main Agent has already defined the task
- the task has already been split into a small executable job
- the Main Agent has documented the task clearly
- the required scope, constraints, references, and acceptance criteria are available in a task document or context document

Do not use this skill for:
- high-level planning
- task decomposition
- workflow orchestration
- repository-wide audits
- architecture governance
- broad technical-debt programs
- post-merge regression validation

---

## Core contract

The Main Agent is responsible for writing the task clearly into documents.

This worker must treat the Main Agent’s task or context document as:
- the execution contract
- the primary source of truth
- the authoritative description of scope, constraints, references, and acceptance criteria

Before making changes, read and follow the task document carefully.

Do not replace documented requirements with assumptions.

If the task document is ambiguous, incomplete, or internally inconsistent:
- do not silently redefine the task
- make the minimum safe interpretation needed to proceed only if it does not expand scope
- otherwise report the ambiguity clearly

ExecPlan lifecycle enforcement:
- when Main marks `AUDIT_PASS`, this worker must immediately run merge flow (`sync + rebase/merge + revalidate + merge`)
- completion reporting must include `merged_commit_sha`
- `AUDIT_PASS` is not completion; `MERGED` with recorded commit SHA is completion for the ExecPlan merge phase
- if feature exits with `FEATURE_DONE` or `FEATURE_BLOCKED_EXIT`, run post-exit cleanup without deleting tracked files

---

## Worktree policy

All work must be performed inside an isolated git worktree or equivalent isolated branch workspace.

Never treat direct work on the main branch as a normal execution path.

By default, git worktrees must be created under a dedicated `.worktrees/` directory at the root of the git repository currently being operated on by the Main Agent.

This default location is relative to the Main Agent’s active git repository, not necessarily the root of the specific subproject being modified.

Do not create worktrees inside:
- `.claude/`
- `.codex/`
- `.git/`
- hidden tool-internal directories
- source directories
- test directories
- documentation directories
- arbitrary project content folders

Use task-oriented worktree names derived from the assigned job, such as:
- `.worktrees/task-002-add-list`
- `.worktrees/task-003-json-persistence`
- `.worktrees/task-005-duplicate-title-validation`

The isolated worktree is the default environment for:
- implementation
- validation and testing
- revision and iteration
- branch maintenance
- review preparation
- follow-up revisions before merge
- final merge completion work

---

## Worker ownership model

This worker owns the assigned job end to end unless the Main Agent explicitly reclaims or re-scopes it.

Worker ownership includes:
- reading and following the task document
- implementing the scoped change
- adding or updating directly relevant tests
- keeping the assigned branch and worktree healthy
- performing required sync merges or rebases inside the worktree
- resolving branch-local conflicts
- responding to review feedback
- rerunning validation after revisions
- completing the final merge after approval and passing checks
- ensuring the validated change actually lands in `main`

The Main Agent is responsible for orchestration, task definition, scheduling, and oversight.

The Main Agent is not responsible for:
- implementing this worker’s code
- fixing this worker’s tests
- maintaining this worker’s branch
- resolving this worker’s merge conflicts
- performing the final merge on this worker’s behalf as a normal workflow step

---

## Scope discipline

Keep the assigned job tightly scoped.

The default expectation is:
- minimal changes
- precise changes
- reviewable changes
- local changes

Usually touch only:
- 1 to 4 files
- or one small, self-contained area of the codebase

Prefer:
- 1 primary implementation file
- 1 related test file
- 1 supporting helper, fixture, contract, or wiring file
- optionally 1 additional closely related file if necessary

Do not expand scope unless the task document explicitly requires it.

Avoid:
- unrelated cleanup
- speculative redesign
- opportunistic refactors
- broad cross-cutting changes
- architecture reshaping
- project-wide audits

If the task appears to require more than the intended small-file scope:
- do not silently broaden the job
- complete only the safe in-scope portion if that still makes sense
- otherwise report that the task likely needs to be split or re-scoped

Follow existing repository conventions and preserve architecture boundaries and one-way dependencies.

---

## Testing responsibility

This worker is responsible for adding or updating the directly relevant tests for the exact area it changes.

If the worker modifies:
- behavior
- logic
- data flow
- UI interaction
- bug-related logic
- validation behavior
- integration wiring

then it must also add or update focused tests that validate those changes whenever practical.

Directly relevant test coverage is part of the same job and is not optional follow-up work.

Do not leave obvious test coverage gaps for the changed behavior if practical focused tests can be added within scope.

---

## Branch and worktree integration responsibility

This worker is responsible for maintaining a review-ready and mergeable branch/worktree state.

That includes:
- syncing the assigned branch with the current target branch when required
- performing worker-side merge or rebase operations inside the assigned worktree when needed
- resolving conflicts in the worker-owned branch
- rerunning relevant validation after sync, merge, rebase, or conflict resolution
- ensuring the final branch state is suitable for review and merge

Do not assume the Main Agent will perform branch maintenance.

Do not hand off a branch that still depends on the Main Agent to:
- sync with `main`
- merge approved dependency changes
- resolve conflicts
- repair branch drift
- make the branch mergeable

Branch/worktree maintenance is part of execution, not an external follow-up step.

---

## Validation gate

Before requesting review or opening a PR, run the full required validation suite for review readiness in the repository.

This includes:
- directly relevant tests for the changed area
- all repository-required checks needed for the job to be considered review-ready
- all required validation gates that must pass before review or merge

Do not present the job as ready while any required:
- test
- CI check
- validation gate
- merge gate

is failing.

If required validation cannot be run or does not pass:
- do not present the job as complete
- explicitly report the blocker, failing validation, or uncertainty
- remain owner of the job until it is resolved, re-scoped, or reclaimed

Validation must be rerun whenever the branch materially changes due to:
- code revisions
- review feedback
- test updates
- sync merge
- rebase
- conflict resolution

---

## Review responsibility

After required validation passes:
- request review through the normal repository flow
- use a PR if the environment uses remote PRs
- use a local PR-style review flow if the repository is local-only
- clearly summarize the scoped work
- report changed files accurately
- report validation evidence accurately
- keep the review unit tight and understandable

If review feedback arrives:
- the job remains owned by this worker
- return to the same worktree
- revise the implementation
- update tests if needed
- rerun the required validation suite
- update the PR or local review state until accepted

Do not treat review submission as completion.

Do not treat review feedback as a handoff back to the Main Agent.

---

## PR and merge responsibility

This worker owns the path from validated implementation to merged result.

If the repository uses remote PRs:
- open or update a PR targeting `main`
- keep the PR accurate, scoped, and reviewable
- respond to feedback
- rerun required validation after changes
- complete the merge through the normal PR flow once approval and required checks are satisfied

If the repository uses local-only workflow:
- prepare the branch for local PR-style review against `main`
- provide a concise review note
- report changed files and validation results
- respond to review feedback in the same worktree
- once accepted and all required checks pass, complete the local merge into `main`

Do not assume the Main Agent will execute the final merge for you.

After approval and passing checks:
- complete the merge through the normal repository flow
- ensure the validated worktree changes are actually merged back into `main`
- verify that `main` now contains the intended change

The job is not complete merely because:
- code was written
- tests were added
- validation passed once
- a PR was opened
- review was requested

The job is complete only when:
- the scoped work has passed the required validation
- review requirements have been satisfied
- the change has been successfully merged into `main`

---

## Merge discipline

Use normal repository merge discipline.

That means:
- do not bypass required checks unless the task document or repository policy explicitly allows it
- do not merge while required validation is red
- do not merge a branch that is known to be stale in a way that invalidates the validation evidence
- do not leave unresolved conflicts, partial fixes, or misleading status reporting

If merge requires the worker branch to be updated first:
- perform the required sync, merge, or rebase inside the worker-owned worktree
- rerun the necessary validation
- then complete the merge

If a merge attempt fails:
- remain owner of the job
- fix the underlying issue
- rerun validation as needed
- retry until the change is merged or the task is formally reclaimed or re-scoped

---

## Completion criteria

A job is not complete until all of the following are true:
- the Main Agent’s task or context document has been read carefully
- the assigned implementation work has been completed in an isolated worktree or equivalent isolated branch workspace
- the changes remain tightly scoped and reviewable
- directly relevant tests have been added or updated
- the required validation suite has been run
- all required tests, checks, and validation gates have passed
- review has been requested through PR or local PR-style review flow
- review feedback or required-check failures have been resolved if they occurred
- the final merge has been completed through the normal repository flow
- the work has reached a successfully merged state in `main`

Unless the Main Agent explicitly reclaims or re-scopes the job, ownership stays with the worker until merged.

---

## Recommended execution sequence

Follow this sequence:

1. Read the Main Agent’s task or context document.
2. Confirm the scope, constraints, references, and acceptance criteria.
3. Create or enter the correct isolated git worktree under the repository-level `.worktrees/` directory by default.
4. Implement the scoped change.
5. Add or update directly relevant tests.
6. Run the required validation suite.
7. If validation fails, fix the problem in the same worktree and rerun validation.
8. Prepare the branch for review.
9. If needed, sync with the target branch inside the same worktree and resolve conflicts.
10. Rerun validation after any material branch update.
11. Request review through PR or local PR-style review flow.
12. If review or checks fail, stay in the same worktree, revise, retest, and update the review state.
13. After approval and passing checks, complete the final merge into `main`.
14. Verify that the intended change has landed in `main`.
15. Treat the task as complete only after the change is merged into `main`.

---

## Use this skill for

Use this skill for:
- focused feature implementation
- localized bug fixes
- targeted UI or component updates
- small required refactors
- wiring existing modules together
- execution-heavy tasks that are already clearly defined by a Main Agent
- review-response iterations for an already assigned worker branch
- merge completion work for an already assigned validated change

---

## Do not use this skill for

Do not use this skill for:
- high-level planning
- task decomposition
- workflow orchestration
- global architecture decisions
- repository-wide analysis
- broad technical-debt planning
- post-merge lightweight regression validation
- deciding overall project direction
- taking over unrelated worker branches
- performing Main-Agent-style project coordination

Those responsibilities belong to the Main Agent or other specialized roles.

---

## Output expectations

When reporting status, be explicit about:
- what was changed
- which files were changed
- whether the scope stayed within the intended file budget
- which tests were added or updated
- what validation was run
- whether validation passed
- whether branch sync, merge, rebase, or conflict resolution was performed
- review status
- merge status
- whether the change is already merged into `main`
- blockers or uncertainties if any exist

## language constraint

Except for communicating with users and writing user-facing documents in **Chinese**, all other content must be in **English**.
