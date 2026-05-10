---
name: bdd-product-craft
description: >
  Transform product requirements into BDD documents before writing any code.
  Use this skill whenever the user asks to create a feature, build a component, add
  functionality, or modify behavior. Trigger on phrases like: user story, feature request,
  new component, add support for, implement, behavior change, business rule, interaction
  flow, or product requirement. Even if the user does not explicitly mention "BDD"
  or "tests", use this skill to align on requirements first. Do NOT trigger
  for pure visual changes (colors, fonts, spacing) or copy-only edits.
---

# BDD Product Craft

Transform product requirements into structured BDD documents. Goal: align on
business logic before writing code.

**Do NOT use when:** only visual tweaks, copy edits, pure refactoring with no behavior
change, or user explicitly demands to skip straight to coding.

## Workflow

```
Restate → Explore → Clarify → Write → Review → Confirm
```

### Step 1: Minimal Restatement

Restate the core requirement in 2-3 sentences. Ask "Is that correct?" Iterate until aligned.

### Step 2: Explore Code Context

Spawn an explore agent to understand project landscape (architecture, terminology,
dependencies). Goal: use accurate domain terms in the BDD document, not to design
technical solutions.

### Step 3: Clarification Questions

Combine explore findings into a complete restatement, then ask only genuinely needed
questions.

| Type | When to Resolve | Example |
|------|-----------------|---------|
| **Blocking** | Must resolve now | "Do comments require login, or anonymous posting allowed?" |
| **Detail** | Record, refine during writing | "Sort chronologically or reverse-chronologically?" |

### Step 4: Write BDD Document

Write `.md` file to `docs/feature/` folder (create if missing). One file per user-understandable
feature, kebab-case filename.

**Structure:**
```markdown
# [Feature Name]

## Background
As a [role], I want [goal], so that [value].

## Scenario: [description]

**Preconditions**
- [initial state 1]
- [initial state 2]

**Actions**
1. [user action 1]
2. [user action 2]

**Expected Results**
- [expected result 1]
- [expected result 2]
```

**Principles:**
- Use project's domain terms from explore results
- Each scenario = one concrete behavioral path
- Cover: happy path + major error paths + key boundaries
- Scenarios describe **business behavior**, not technical implementation
  - ✅ "When the user clicks the submit button"
  - ❌ "When the submit API is called"

### Step 5: Review

Spawn `bdd-reviewer` agent to check scenario completeness and business logic soundness.
Fix issues. Re-review if critical gaps found.

### Step 6: Confirm

Present final document with visual summary:

```
┌─────────────────────────────────────────────────────────┐
│  ✅ BDD Document Ready for Review                        │
├─────────────────────────────────────────────────────────┤
│  📋 Feature: [Feature Name]                              │
│  🔢 Scenarios: [N] total                                 │
│     • [N] happy path                                     │
│     • [N] error path                                     │
│     • [N] boundary / edge case                           │
│  ❓ Open details for next iteration: [list or "none"]    │
└─────────────────────────────────────────────────────────┘
```

Explain coverage, open details, and that this skill's job ends here — user proceeds to
technical implementation after confirmation.

## Common Pitfalls

- **Over-engineering**: Don't verify internal state ("database should have one record").
  BDD documents align business understanding, not test scripts.
- **Wrong granularity**: One `.md` file = one **user-understandable feature**, not one
  API endpoint or component.
- **Missing error paths**: At minimum cover input validation failure, permission denied,
  and network errors.
- **Premature optimization**: Don't discuss technical solutions during BDD (Redis vs
  database? REST vs GraphQL?). Those belong in the plan phase.

## Relationship with long-task-executor

1. `bdd-product-craft`: Produces confirmed product requirements (BDD document)
2. `long-task-executor`: Designs technical plan and implements based on confirmed BDD

Don't skip BDD confirmation. If user urges coding: "The BDD document ensures we share
the same understanding and avoids rework. Once confirmed, I'll immediately proceed to
technical implementation."
