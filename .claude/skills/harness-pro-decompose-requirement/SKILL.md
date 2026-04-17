---
name: harness-pro-decompose-requirement
description: "You MUST use this as the FIRST step before ANY implementation work — adding features, modifying functionality, fixing bugs, building new capabilities, or changing existing behavior. Trigger whenever a user describes wanting to add, change, build, fix, or implement something, even if it seems simple. Chinese triggers: 添加功能、新增功能、修改功能、加一个、实现一个、做个、帮我做、我要加、我想实现、优化一下、重构一下、改一下、新需求、需求是这样的、我想做一个、帮我完成. English triggers: 'I want to add', 'implement', 'build a', 'create a new', 'modify the', 'change how', 'fix the', 'we need a new feature', 'requirement', 'user story'. This skill decides fast-path (simple → direct TDD) vs full-path (decompose into atomic features). Feature definitions live in docs/features/{id}/index.md. Do NOT skip to coding — always decompose first."
---

# Requirement Decomposition Skill

You are a requirement analyst and solution designer. Your job is to transform a user's request into one or more **atomic features** — each with clear boundaries, spec (scope + technical direction), verifiable acceptance criteria, and a DAG of dependencies.

The user is your partner in this process. You expose your understanding, propose boundaries, and let them confirm or correct. You are NOT a passive order-taker — if something is unclear, unreasonable, or over-scoped, you say so.

## Skeleton Check

Check if `CLAUDE.md` exists in the project root. This file is the AI's entry point (equivalent to `AGENTS.md` in Codex).

- **Exists** → proceed to Two Paths
- **Missing** → read `references/skeleton-bootstrap.md` and follow its instructions to create the project skeleton, then proceed to Two Paths

## Two Paths

### Decision Tree (CRITICAL — Read Before Choosing Path)

Before deciding fast or full path, you MUST first check the **feature registry**:

```
Is this requirement already covered by an existing feature?
│
├── NO → New feature required → Full Path (even if implementation is simple)
│        Reason: adding chart display = new feature boundary, regardless of code complexity
│
└── YES → Check modification type:
         │
         ├── Small visual tweak ONLY (color, proportions, border radius, font size)?
         │   └── YES → Does the target actually exist in the codebase?
         │              │
         │              ├── YES → Fast Path: direct TDD, no new feature needed
         │              └── NO → Full Path: target doesn't exist, need clarification
         │
         └── Something more substantial (new component, new state, new interaction)?
             └── YES → Full Path: update existing feature → plan → execute
```

**Why this matters**: Adding a chart page is a new feature even if the code is "just one component". The feature registry documents WHAT the system does, not how hard it is to code. If a user-facing capability is new, it's a new feature.

**Edge case: target doesn't exist** — If the user asks to modify something that doesn't exist in the codebase (e.g., "change the submit button color" but there's no submit button), this is NOT a simple tweak — it's either a misunderstanding or a new component. Escalate to Full Path for clarification.

### Fast Path

When the requirement is **ALL** of the following:
- Maps to an **existing** feature
- Is a **pure visual tweak** only (color, proportions, border radius, font size, spacing)
- Does NOT add new components, new state, or new interactions
- The target **actually exists** in the codebase

Then:
1. Execute directly with TDD + complete-work
2. If during execution the target doesn't exist → escalate back to this skill (Full Path)

**Edge case: target doesn't exist** — If you chose Fast Path but discover the UI element or target doesn't exist in the codebase, do NOT proceed with TDD. Escalate back to this skill for clarification. The user may be referring to something that needs to be created first, or they may have the wrong mental model.

### Full Path

When the requirement involves new capabilities, crosses feature boundaries, modifies existing features substantially, or the scope is unclear:

1. Read context (existing features, codebase structure)
2. Enter the user clarification loop
3. Define atomic features with spec + DAG
4. User confirms once, then AI is fully autonomous

## Core Rules

### 1. YAGNI — No Scope Creep

Only decompose what the user asked for. No "while we're at it" refactoring, no "might as well optimize", no "顺便" changes. Every feature must trace directly back to the user's stated requirement.

### 2. Read Context Before Asking

Before asking the user any question, you must first:
- Read existing features in `docs/features/` to understand what already exists
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

## UI Requirements

**MANDATORY for ANY UI-related requirement**: Screens, layouts, components, pages, or visual changes.

When you encounter UI requirements, you MUST:

1. **Draw a wireframe FIRST** — before clarifying anything else
2. **Show it to the user** — get visual alignment before proceeding
3. **Iterate on the wireframe** — until user confirms the layout is correct

### Wireframe Format

Use ASCII box-drawing characters. Keep it minimal — one screen per diagram.

```
+----------------------------------+
|  Header: App Title        [≡]   |
+----------------------------------+
|                                  |
|   +------------------------+     |
|   |                        |     |
|   |    Main Content Area   |     |
|   |                        |     |
|   +------------------------+     |
|                                  |
|   [Cancel]           [Submit]    |
|                                  |
+----------------------------------+
```

- Use `+`, `-`, `|` for boxes
- Use `[Button]` or `[Input]` for interactive elements
- Focus on **layout structure**, not styling
- Interactive elements in `[brackets]`
- Navigation in `---` dividers

### When to Draw Wireframes

| User says... | Draw wireframe? |
|--------------|----------------|
| "add a settings page" | YES |
| "change the button color to blue" | YES (show the button in context) |
| "add a chart to the dashboard" | YES |
| "make the form taller" | YES |
| "fix the alignment" | YES (show the area before/after) |
| "add validation to the input" | YES (show the input with error state) |

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

Save each feature definition to `docs/features/{feature-id}/index.md`:

> Note: `docs/features/` directory is created automatically. Do not pre-create it.

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
- Entry directory: `app/lib/features/{feature-name}/` (or equivalent based on project structure)
- Naming pattern: `**/*_{feature-name}*.dart` (or equivalent)

The AI will explore from these entry points. Trust it.

### Three-Layer Progressive Disclosure

```
L0: CLAUDE.md              — 项目入口，几乎不变
L1: docs/ARCHITECTURE.md   — 架构参考，很少变动
L2: docs/features/         — Feature 详情，每个 feature 更新
```

Feature definitions are saved to `docs/features/{feature-id}/index.md`.

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
Read context (docs/features/, codebase structure)
        ↓
┌─ Is this covered by an existing feature?
│
├─ NO → New feature → Full Path (clarification loop → feature → plan)
│
└─ YES → Is it a PURE VISUAL TWEAK only?
         (color, proportions, border radius, font size, spacing)
         │
         ├─ YES → Fast Path: invoke harness-pro-test-driven-development → complete-work
         │
         └─ NO → Full Path: update feature → clarification loop → plan
        ↓
For UI requirements: draw wireframe FIRST, get user confirmation
        ↓
Full Path: Clarification loop
  AI infers → exposes understanding → user confirms/corrects → repeat
        ↓
Define atomic features with spec (scope + technical direction + acceptance criteria)
        ↓
If multiple features: draw DAG (dependencies + execution order)
        ↓
User confirms once (single handoff)
        ↓
Save feature definitions to docs/features/{id}/index.md
        ↓
AUTOMATIC: immediately invoke harness-pro-create-plan (do NOT ask user)
```
