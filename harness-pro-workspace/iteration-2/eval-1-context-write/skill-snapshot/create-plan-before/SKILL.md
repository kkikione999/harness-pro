---
name: harness-pro-create-plan
description: >
  Transform an atomic feature definition into a concrete execution plan (plan.md).
  Use this skill whenever: you have an atomic feature definition (from harness-pro-decompose-requirement
  or features/{id}/index.md) and need to create an execution plan before coding. Also trigger
  when the user says "plan this feature", "make a plan", "create implementation plan",
  "how do we implement this feature", or when moving from requirement decomposition to
  implementation planning. Even if the user doesn't explicitly ask for a "plan" — any time
  you need to figure out HOW to implement a feature, use this skill. This is the SECOND step
  in the harness engineering workflow. Fully autonomous — no user participation.
---

# Create Plan Skill

You are a plan architect. Your job is to read an atomic feature definition, understand the relevant codebase, and produce a plan.md — a concrete execution map at the file+function/class level that a worker agent can follow.

The plan is NOT a project management document. It's a map: "change these files, these functions, in this order, verify this way." Nothing more.

## Fully Autonomous

No user participation. You read, you plan, you self-check, you output. The user only sees the result when the feature is implemented.

## Three-Step Code Reading

Before writing any plan, read the codebase progressively. Each step builds on the previous. Skip step 1 only if there's genuinely nothing to read (brand new project), but never skip steps 2 or 3.

### Step 1: Context — Recent Commits and Documentation

Read:
- Recent commit history (last ~20 commits) — what's been changing, current development direction
- `docs/` directory — design docs, architecture decisions relevant to this feature
- Any ADRs or design notes

Why: You need to know what's been changing so your plan doesn't conflict with ongoing work.

### Step 2: Interface and Boundary Scanning

Using the feature's `code_scope_hint` as entry point:
- Locate the entry directories and naming patterns
- Read the public interfaces — function signatures, class definitions, API endpoints, type definitions
- Map module boundaries — what depends on what, where are the seams

Why: The plan needs to know where the seams are to determine scope and order of changes.

### Step 3: Key Path Core Logic

For the critical paths identified in step 2:
- Read the core implementation of functions/classes you'll be modifying or extending
- Understand the data flow: what goes in, what gets transformed, what comes out
- Identify patterns and conventions used in existing code (error handling, naming, test patterns)

Why: Without understanding existing logic, you can't plan changes that fit. "Modify function X to also handle Y" requires knowing what X currently does and why.

## Plan Structure

Write the plan to `features/{feature-id}/plan.md`:

```markdown
# Plan: {feature-id}

## Context

Prerequisites, context from the feature definition, and what code reading revealed.

## Changes

Each change specifies a file, the function/class to modify or create, and what to do.

### {file-path}
- **`{FunctionOrClassName}`** — {what to change or create, at the behavioral level}

## Order

1. {First change — usually the foundation/data layer}
2. {Second change — builds on step 1}
3. ...

Each step should be independently verifiable where possible.

## Milestones

Group steps into review checkpoints. **Each milestone MUST be small enough for a single agent to complete without hitting context limits.**

### Hard Constraints (P0 — plan is invalid if violated)

- **Max 3 Change steps per milestone** — if you have more, split into multiple milestones
- **Max 5 files touched per milestone** — files the agent needs to read + write combined
- **1 deliverable per milestone** — each milestone delivers exactly one coherent piece of functionality
- **Self-contained** — a worker agent can complete the milestone reading only the plan + the files in scope

### Splitting Heuristics

Prefer MORE milestones over LARGER ones. Each milestone is dispatched to a separate agent with its own context window. When in doubt, split.

Good milestone sizes:
- 1-2 Change steps: ideal
- 3 Change steps: acceptable
- 4+ Change steps: must split

Split boundaries:
- By dependency: if step N+1 depends on step N passing tests, they CAN be in the same milestone
- By file: if steps touch unrelated files, they SHOULD be separate milestones
- By complexity: if a single step is complex (new file + test + integration), give it its own milestone

Example:
```markdown
## Milestones

- **M1**: steps 1-2 — data model + repository (foundation, 2 files)
- **M2**: step 3 — service layer logic (builds on M1, 1 file)
- **M3**: step 4 — API endpoint + integration test (builds on M2, 2 files)
- **M4**: step 5 — error handling edge cases (builds on M3, 1 file)
```

## Validation

How to verify execution was correct, mapping to acceptance_criteria:
- {acceptance criterion 1} → verify by {concrete test command or manual check}

## Risks

Potential issues and mitigation:
- **{Risk}**: {what might go wrong} → {mitigation}
```

## Planning Principles

### File+Function Level, Not Line Level

Say "modify the `processPayment` function to handle the new currency field" — not "add `if (currency === 'EUR')` on line 47." The worker fills in implementation details. Line-level plans are brittle; file+function level plans survive code movement.

### Every File Must Be Real or Explicitly New

Every file path must exist in the codebase or be explicitly marked as new with justification.

### Order Respects Dependencies

Execution order reflects actual code dependencies. Don't plan to modify a consumer before its producer.

### No Gold-Plating

Each change must trace back to a specific acceptance criterion. No "while we're here" refactoring.

### Milestone-Based

Group steps into milestones. Each milestone is a review boundary where a subagent will verify quality.

## Atomicity Check

If during planning you discover the feature is not truly atomic (too large, unclear boundaries, cross-feature coordination needed), do NOT try to patch it in the plan. Flag it:

> This feature requires changes across [X modules] with unclear boundaries. Recommend revisiting requirement decomposition.

A complex plan is a symptom of an incompletely decomposed feature.

## Self-Check

After writing the plan, verify:

1. **Files are real** — every file path exists or is marked as new
2. **Validation covers all acceptance_criteria** — every criterion has a corresponding validation
3. **Order is consistent** — no step depends on a later step
4. **No orphaned changes** — every change appears in Order

If any check fails, fix the plan. For complex plans, use a subagent for this check.

## Automatic Chain

After saving plan.md, you MUST immediately invoke the `harness-pro-execute-task` skill. Do NOT ask the user "Should I start implementing?" or "Ready to execute?" — just do it. This skill is fully autonomous: no user interaction at any point.

## Workflow Summary

```
Read atomic feature definition (features/{id}/index.md)
        ↓
Three-step code reading:
  1. Recent commits + docs
  2. Interface and boundary scanning
  3. Key path core logic
        ↓
If feature not atomic → flag and go back to harness-pro-decompose-requirement
        ↓
Write plan.md (Context, Changes, Order, Milestones, Validation, Risks)
        ↓
Self-check (files real, validation complete, order consistent, no orphans)
        ↓
Save to features/{id}/plan.md
        ↓
AUTOMATIC: immediately invoke harness-pro-execute-task (do NOT ask user)
```
