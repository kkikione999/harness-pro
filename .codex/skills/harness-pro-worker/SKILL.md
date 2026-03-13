---
name: harness-pro-worker
description: Execution-focused worker workflow for small, clearly scoped engineering jobs in a multi-agent workflow. Use this skill only after a Main Agent has already defined a concrete task, split it into a small executable job, and documented the requirements, scope boundaries, references, constraints, and acceptance criteria. This skill is for disciplined implementation, testing, PR submission, and merge completion in an isolated git worktree.
---

# harness-pro-worker

## Purpose

`harness-pro-worker` is an execution-focused worker skill for small, clearly scoped engineering jobs in a multi-agent workflow.

Use this skill only when:
- a Main Agent has already defined the task
- the task has already been split into a small executable job
- the Main Agent has documented the task clearly
- the required scope, constraints, references, and acceptance criteria are available in a task document or context document

Do not use this skill for high-level planning, task decomposition, workflow orchestration, repository-wide audits, architecture governance, broad technical-debt programs, or post-merge regression validation.

---

## Core contract

The Main Agent is responsible for writing the task clearly into documents.

This worker must treat the Main Agent’s task or context document as:
- the execution contract
- the primary source of truth
- the authoritative description of scope, constraints, references, and acceptance criteria

Before making changes, read and follow the task document carefully.

Do not replace documented requirements with assumptions.

---

## Worktree policy

All work must be performed inside an isolated git worktree or equivalent isolated branch workspace.

Never treat direct work on the main branch as a normal execution path.

By default, git worktrees must be created under a dedicated `.worktrees/` directory at the root of the git repository currently being operated on by the Main Agent.

This default location is relative to the Main Agent’s active git repository, not necessarily the root of the specific subproject being modified.

Do not create worktrees inside:
- `.claude/`
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
- PR preparation
- follow-up revisions before merge

---

## Scope discipline

Keep the assigned job tightly scoped.

The default expectation is:
- minimal changes
- precise changes
- reviewable changes
- local changes

Usually touch only:
- 1–3 files
- or one small, self-contained area of the codebase

Do not expand scope unless the task document explicitly requires it.

Avoid:
- unrelated cleanup
- speculative redesign
- opportunistic refactors
- broad cross-cutting changes
- architecture reshaping
- project-wide audits

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

then it must also add or update focused tests that validate those changes whenever practical.

Directly relevant test coverage is part of the same job and is not optional follow-up work.

---

## Validation gate

Before opening a PR, run the full required validation suite for PR readiness in the repository.

This includes:
- directly relevant tests for the changed area
- all repository-required checks needed for the job to be considered PR-ready
- all required validation gates that must pass before review or merge

Do not submit a PR while any required:
- test
- CI check
- validation gate
- merge gate

is failing.

If required validation cannot be run or does not pass:
- do not present the job as complete
- explicitly report the blocker, failing validation, or uncertainty

---

## PR and merge responsibility

After the full required validation suite passes:
- submit a PR targeting the main branch
- clearly summarize the scoped work
- keep the PR reviewable and accurate

If the PR fails review, required checks, or merge requirements:
- the job remains owned by this worker
- return to the same worktree
- revise the implementation
- update tests if needed
- rerun the full required validation suite
- update the PR until it is accepted and merged

Do not treat a failed PR as completed work.

After the PR is approved and all required checks pass:
- complete the merge through the normal PR flow
- ensure the validated worktree changes are actually merged back into the main branch

The job is not complete merely because:
- code was written
- tests were added
- a PR was opened

The job is complete only when:
- the scoped work has passed the required validation
- the PR has been accepted
- the change has been successfully merged into the main branch

---

## Completion criteria

A job is not complete until all of the following are true:
- the Main Agent’s task or context document has been read carefully
- the assigned implementation work has been completed in an isolated worktree or equivalent isolated branch workspace
- the changes remain tightly scoped and reviewable
- directly relevant tests have been added or updated
- the full required validation suite has been run
- all required tests, checks, and validation gates have passed
- a PR targeting the main branch has been submitted
- PR feedback or required-check failures have been resolved if they occurred
- the merge has been completed through the normal PR flow
- the work has reached a successfully merged state in the main branch

Unless the Main Agent explicitly reclaims or re-scopes the job, ownership stays with the worker until merged.

---

## Recommended execution sequence

Follow this sequence:

1. Read the Main Agent’s task or context document.
2. Confirm the scope, constraints, references, and acceptance criteria.
3. Create or enter the correct isolated git worktree under the repository-level `.worktrees/` directory by default.
4. Implement the scoped change.
5. Add or update directly relevant tests.
6. Run the full required validation suite.
7. If validation fails, fix the problem in the same worktree and rerun validation.
8. Once validation passes, submit a PR targeting main.
9. If review or checks fail, stay in the same worktree, revise, retest, and update the PR.
10. After approval and passing checks, complete the merge.
11. Treat the task as complete only after the change is merged into main.

---

## Use this skill for

Use this skill for:
- focused feature implementation
- localized bug fixes
- targeted UI or component updates
- small required refactors
- wiring existing modules together
- execution-heavy tasks that are already clearly defined by a Main Agent

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

Those responsibilities belong to the Main Agent or other specialized roles.

---

## Output expectations

When reporting status, be explicit about:
- what was changed
- which files were changed
- which tests were added or updated
- what validation was run
- whether validation passed
- PR status
- merge status
- blockers or uncertainties if any exist