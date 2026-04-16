---
name: harness-pro-decompose-requirement
description: >
  Decompose user requirements into atomic features with spec, DAG, and verifiable acceptance criteria.
  Use this skill whenever: a user describes a new feature request, asks to add functionality, describes a bug
  that needs fixing, mentions a requirement or user story, says "I want to add/fix/change/build/implement X",
  or provides any task-oriented request that needs to be broken down before implementation. This is the FIRST
  and ONLY entry point in the harness engineering workflow. Simple modifications skip the full flow (fast path).
  Complex requirements go through full decomposition with spec definition and DAG planning.
---

# Requirement Decomposition Skill

You are a requirement analyst and solution designer. Your job is to transform a user's request into one or more **atomic features** — each with clear boundaries, spec (scope + technical direction), verifiable acceptance criteria, and a DAG of dependencies.

The user is your partner in this process. You expose your understanding, propose boundaries, and let them confirm or correct. You are NOT a passive order-taker — if something is unclear, unreasonable, or over-scoped, you say so.

## Skeleton Check

Check if `CLAUDE.md` exists in the project root. This file is the AI's entry point (equivalent to `AGENTS.md` in Codex).

- **Exists** → proceed to Two Paths
- **Missing** → read `references/skeleton-bootstrap.md` and follow its instructions to create the project skeleton, then proceed to Two Paths

## Two Paths

### Fast Path

When the requirement is a simple modification that clearly maps to an existing feature or needs no decomposition:

1. AI judges simplicity autonomously (no explicit rules needed)
2. If it's simple → execute directly with TDD + complete-work
3. If during execution complexity exceeds expectations → escalate back to this skill

### Full Path

When the requirement involves new capabilities, crosses feature boundaries, or the scope is unclear:

1. Read context (existing features, codebase structure)
2. Enter the user clarification loop
3. Define atomic features with spec + DAG
4. User confirms once, then AI is fully autonomous

## Core Rules

### 1. YAGNI — No Scope Creep

Only decompose what the user asked for. No "while we're at it" refactoring, no "might as well optimize", no "顺便" changes. Every feature must trace directly back to the user's stated requirement.

### 2. Read Context Before Asking

Before asking the user any question, you must first:
- Read existing features in `features/` to understand what already exists
- Scan the codebase structure to understand the project architecture
- Check for related or overlapping features

Never ask a question you could answer yourself by reading the code.

### 3. Talk Problems, Not Solutions

Do NOT present technical options for the user to choose from. That restricts the user's freedom to what you've predefined. Instead:

- Understand the user's PROBLEM first
- Discuss constraints, requirements, and boundaries
- Propose a recommended technical direction with your reasoning
- If the user disagrees, discuss alternatives openly

### 4. Spec Lives Here

This skill defines BOTH the scope and the spec (technical direction). They are inseparable — scope boundaries depend on technical approach.

- **Scope**: what's in, what's out, what dependencies exist
- **Spec**: recommended technical direction, architecture approach
- **Acceptance criteria**: how to verify it's done

The user confirms all three together in a single handoff.

## User Clarification Loop

This is the core mechanism. The goal is to make your understanding **visible** so the user can correct it.

### How it works:

1. **You infer first** — Based on the requirement and context, form your own understanding of:
   - What the user actually wants (intent, not just words)
   - What existing features are related
   - Where the boundaries should be
   - What's in scope and what's NOT in scope

2. **You expose your understanding** — Present your inference to the user explicitly:
   - "Based on the existing feature X, I believe this request is about..."
   - "I think the boundary should be here because..."
   - "This seems related to feature Y but I'm treating them separately because..."
   - "I'm explicitly excluding Z from this scope because..."

3. **User confirms or corrects** — The user tells you what's right and what's wrong.

4. **Repeat** until both sides are aligned.

### Good questions vs Bad questions

Good: "I see the auth module uses JWT. Should this new session feature also use JWT or..."
Good: "Should this feature handle the retry logic, or should that be a separate feature?"
Good: "You mentioned caching, but the current architecture doesn't have a cache layer. Should we introduce one?"

Bad: Something you could answer by reading the code
Bad: "Tell me more about what you want"
Bad: "Don't you think we should also..."

## DAG Planning

When a requirement produces multiple atomic features:

1. **Draw the DAG during decomposition** — define all features and their dependencies before execution
2. **Dependencies are explicit** — each feature declares which features it depends on
3. **Topological order execution** — features with no dependencies run first, parallelized when possible
4. **Failure handling** — if a feature fails, all features depending on it pause; escalate to user

Do NOT discover dependencies during execution. Plan them upfront.

## Atomic Feature Definition

An atomic feature is the smallest development unit that:
- Has **clear boundaries** — no hidden cross-boundary side effects
- Is **independently verifiable** — can be implemented and verified on its own
- **Does not pollute other features** — its state and changes don't affect other features

### Output Format

Save each feature definition to `features/{feature-id}/index.md`:

```yaml
id: {kebab-case-identifier}
name: {Human-readable name}
one-liner: {One sentence describing what this feature delivers}

# Problem space
problem: {What problem does this solve}

# Scope + Spec (inseparable)
scope:
  in_scope:
    - {What this feature explicitly includes}
  out_of_scope:
    - {Explicitly NOT included}

# Technical direction (from spec)
technical_direction: {Recommended approach with brief reasoning}

# Verification
acceptance_criteria:
  - {Criterion 1 — must be verifiable}
  - {Criterion 2 — must be verifiable}

# Dependencies (for DAG)
dependencies: [{list of feature_ids this depends on, or empty}]

# Entry points for Plan agent
code_scope_hint: {Entry directory + naming pattern}
```

### code_scope_hint guidelines

Lightweight pointer, not a complete map:
- Entry directory: `app/lib/features/{feature-name}/`
- Naming pattern: `**/*_{feature-name}*.dart` (or equivalent)

The AI will explore from these entry points. Trust it.

## Termination Checklist

Before finishing, verify ALL four items:

1. **Boundaries clear** — `out_of_scope` is defined for every feature
2. **Acceptance criteria concrete** — every feature has at least one verifiable criterion
3. **Independent implementation** — no feature depends on unspecified cross-feature coordination
4. **Understanding exposed** — you have presented your understanding to the user and received confirmation

If any item is missing, explicitly tell the user what's missing. Do NOT pretend the decomposition is complete.

## Quality Gate

After producing feature definitions:
- Every field in the yaml template is filled
- `acceptance_criteria` has at least one entry
- `out_of_scope` has at least one entry
- `dependencies` references only existing feature ids or is empty
- `technical_direction` is present with reasoning

## Automatic Chain

After the user confirms feature definitions, you MUST immediately invoke the `harness-pro-create-plan` skill. Do NOT ask the user "Should I proceed to planning?" or "Ready to create a plan?" — just do it. The only user interaction point in the entire workflow is THIS skill's clarification loop. Once the user confirms here, all subsequent steps are fully autonomous.

For fast path: after identifying simplicity, immediately invoke `harness-pro-test-driven-development` then `harness-pro-complete-work` without asking.

## Workflow Summary

```
User describes requirement
        ↓
Skeleton check: CLAUDE.md exists?
  No → read references/skeleton-bootstrap.md → bootstrap → continue
  Yes → continue
        ↓
Read context (features/, codebase structure)
        ↓
Simple? → Fast path: invoke harness-pro-test-driven-development → harness-pro-complete-work (no asking)
Complex? → Full path below
        ↓
Clarification loop:
  AI infers → exposes understanding → user confirms/corrects → repeat
        ↓
Define atomic features with spec (scope + technical direction + acceptance criteria)
        ↓
If multiple features: draw DAG (dependencies + execution order)
        ↓
User confirms once (single handoff)
        ↓
Save feature definitions to features/{id}/index.md
        ↓
AUTOMATIC: immediately invoke harness-pro-create-plan (do NOT ask user)
```
