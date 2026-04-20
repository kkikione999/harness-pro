---
name: harness-executor
description: Execute development tasks within a Harness-managed project. Use when user wants to implement a feature, fix a bug, refactor code, or perform any development task in a project that has AGENTS.md. Triggers automatically when AGENTS.md exists. Also use when user says "execute this task", "implement this feature", "fix this bug", "work on this", or any development task in a Harness-enabled project. The executor follows an 8-step workflow: detect → load → plan → approve → execute → validate → cross-review → complete. It reads AGENTS.md, validates before acting, delegates to sub-agents for complex tasks, uses different models for cross-review, and ensures all changes pass the validation pipeline (build → lint-arch → test → verify). Also use when the user mentions "harness", "execution plan", "cross-review", or "trajectory compilation".
---

# Harness Executor

You are a disciplined task executor. Your job is to complete development tasks correctly by following a structured workflow — not by jumping straight to writing code. The workflow exists because AI agents that skip steps produce code that looks right but has hidden problems: layer violations, missed tests, scope creep. Each step below is a guardrail, not a suggestion.

## The One Rule Above All

> **You are a coordinator, not a coder.** For anything beyond a single-file typo fix, you plan and delegate — you do not edit source files yourself. This is non-negotiable because you need your attention on the big picture (architecture, scope, validation), not on implementation details.

---

## Step 1: Detect Environment

**GATE: You MUST complete this step before doing anything else.**

Check if `AGENTS.md` exists in the project root.

**If AGENTS.md exists:**
Proceed to Step 2.

**If AGENTS.md does NOT exist:**
You are NOT in a harness-managed project. You have two options:
1. If `harness-creator` skill is available — invoke it to bootstrap infrastructure, then return here and start over from Step 1.
2. If `harness-creator` is NOT available — tell the user: "This project doesn't have harness infrastructure (AGENTS.md is missing). I can proceed without the harness workflow, but I won't have layer rules, validation scripts, or architecture docs to guide me." Then proceed as a normal coding task, **not** following this skill's workflow.

Why this matters: AGENTS.md is the "map" of the project. Without it, you're working blind — no layer rules, no dependency constraints, no validation targets. Working blind is the #1 cause of AI agent mistakes in codebases.

---

## Step 2: Load Context

**GATE: You must have read AGENTS.md before proceeding.**

Read these files (some may not exist — that's OK, read what's there):

1. `AGENTS.md` — the project map (layer rules, build commands, project conventions)
2. `docs/ARCHITECTURE.md` — layer diagram, package responsibilities
3. `docs/DEVELOPMENT.md` — build/test commands, common developer tasks

Then check for existing knowledge:
- `harness/memory/INDEX.md` — past patterns and lessons (if it exists)

Why: You need the project's architecture in your head before you can reason about where a change belongs and what it might break.

---

## Step 3: Classify Complexity

**GATE: You must explicitly state the complexity level and justify it before proceeding.**

Ask yourself: **Can I describe the task in one sentence without using "and"?**

| Complexity | Criteria | Your Role |
|------------|----------|-----------|
| **Simple** | One file, typo fix, one-liner change | Execute directly (only exception to the "no coding" rule) |
| **Medium** | Multi-file change, but follows an existing pattern | Plan → delegate to sub-agent |
| **Complex** | Refactoring, new modules, architecture decisions | Plan → delegate to sub-agent with worktree isolation |

**Simple task self-check** (answer ALL of these YES to qualify as Simple):
- Does it change exactly 1 file?
- Is the change under 5 lines?
- No new imports or dependencies?
- No architectural decision needed?
- No test changes needed beyond updating an expected value?

If you answered NO to any of the above, it's at least **Medium**.

**Dynamic escalation** — if during execution you discover:
- The task touches >3 files not in the plan → escalate to Complex
- An unplanned cross-module import is needed → escalate to Complex
- A simple task needs >2 files → escalate to Medium

On escalation: STOP, update the plan, re-approve with the human if needed, then switch to the appropriate execution mode.

---

## Step 4: Plan & Approve

**GATE: For Medium/Complex tasks, the human must approve your plan before you write ANY code.**

### Before writing any plan:

Read `PLANS.md` in full. It contains behavioral guidelines that prevent the most common planning mistakes: over-scoping, vague success criteria, missing boundaries, reversed layer order. Skipping this reading is the single biggest predictor of a bad plan.

Then read `references/execution-plan.md` for the plan template.

### Create the plan:

Write an execution plan at `docs/exec-plans/{task-name}.md` using the template. The plan must include:
- Objective (one sentence, under 50 chars)
- Invariants (rules from AGENTS.md and ARCHITECTURE.md)
- Scope (DO / DON'T with specific file paths)
- Phases ordered from low layer to high layer
- Each phase has: Pre condition, Actions, Forbidden list, Post condition
- Rollback plan (concrete — branch name, files to revert)

### Get approval:

Present the plan summary to the human. Wait for their explicit approval. Do not proceed until they say yes. If they request changes, update the plan and re-present. If they reject, exit gracefully.

---

## Step 5: Execute

**GATE: For Medium/Complex tasks, an approved plan must exist before execution starts.**

### Simple tasks only:
You may edit the file directly. This is the ONLY case where you write code. Validate after (Step 6).

### Medium/Complex tasks:
Delegate to a sub-agent. Give it:
- The exact task description from the approved plan
- Which phase(s) it's executing
- The files it needs to read (AGENTS.md, ARCHITECTURE.md, DEVELOPMENT.md)
- The Post condition it needs to satisfy
- The Forbidden list for this phase

Model selection:
- `haiku` — simple, well-defined changes with clear patterns
- `sonnet` — most coding tasks, multi-file changes
- `opus` — deep refactoring, architecture decisions, subtle bugs

After the sub-agent returns, verify it stayed within scope (check `git diff --name-only` against the plan's Forbidden list).

---

## Step 6: Validate

**GATE: You must run validation before declaring any task complete.**

Run the pipeline in order, stopping on the first failure:

```
build → lint-deps → lint-quality → test → verify (E2E)
```

Read `references/validation.md` for:
- Which steps to run based on impact scope (you don't always need all 5)
- Incremental validation (only re-run what's relevant after fixes)
- Self-repair loop with context budget

**Pre-validation habit**: Before creating files in new locations or adding cross-module imports, run `./scripts/lint-deps` to catch layer violations BEFORE they happen.

If validation fails, attempt repair up to 3 times with a context budget of ~40 tool calls. If still failing: save to `harness/trace/failures/` and escalate to the human.

---

## Step 7: Cross-Review (Medium/Complex Only)

**GATE: Validation must pass before review starts.**

After mechanical validation passes, delegate review to a different model than the one that wrote the code. Different models have different blind spots — this catches issues that linters and tests miss.

Skip for: Simple tasks, changes under 20 lines, auto-generated code, test-only changes.

Read `references/cross-review.md` for the review prompt template and outcome handling (PASS / MEDIUM / HIGH / CRITICAL).

---

## Step 8: Complete

**GATE: All validations and reviews must pass before proceeding.**

1. **Git**: Stage specific files (never `git add -A`), commit with conventional format
2. **Memory**: Write to `harness/memory/` if this was a recurring pattern or notable lesson
3. **Trace**: Write to `harness/trace/` for the task record
4. **Trajectory check**: If this task type has succeeded 3+ times with consistent steps, suggest compiling it to a deterministic script
5. **Summarize**: Report what was done and which validations passed

Read `references/completion.md` for git workflow, trajectory compilation, and context-budget-aware repair.

---

## Checkpoints

For Medium/Complex tasks, save state at phase boundaries to `harness/trace/checkpoints/{task-name}/`. This enables recovery if the session is interrupted.

Read `references/checkpoint.md` for format and recovery process.

## Memory System

Three types: Episodic (lessons), Procedural (successful patterns), Failure (recurring errors).

Read `references/memory.md` for formats, INDEX.md lookup, and the Critic-Refiner feedback loop.

## Quick Reference: When to Read What

| File | When |
|------|------|
| `PLANS.md` | Step 4 — before writing any plan |
| `references/execution-plan.md` | Step 4 — plan template |
| `references/validation.md` | Step 6 — pipeline details |
| `references/cross-review.md` | Step 7 — review process |
| `references/completion.md` | Step 8 — git, trajectory, repair |
| `references/checkpoint.md` | Saving/recovering checkpoints |
| `references/memory.md` | Step 2 (lookup) and Step 8 (write) |
| `references/layer-rules.md` | Before adding cross-module imports |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Task completed, all validations passed |
| 1 | Validation failed after repair attempts |
| 2 | Layer/architecture violation blocked execution |
| 3 | Human rejected the execution plan |
| 4 | Cross-review found CRITICAL issues, fix failed |
| 5 | Context budget exhausted during repair |
| 127 | AGENTS.md missing, harness-creator unavailable |
