# Step 1 — Load Requirement

Goal: discover, parse, and normalize the user's requirement into a unified internal structure — regardless of whether the input is a BDD document, a PRD, a user story, an issue description, a file path, or free-form conversation text.

## Source priority

Check sources in this order. Use the first match.

| Priority | Source | How to detect |
|----------|--------|---------------|
| 1 | **BDD document** in `docs/feature/*.md` | File exists, contains Scenario / Given-When-Then blocks |
| 2 | **Explicit file path** from the user | User said "implement the requirements in X" or referenced a specific file |
| 3 | **Confirmed requirement artifact** in conversation | A structured requirement block from a prior skill (e.g. bdd-product-craft output pasted inline) |
| 4 | **Free-form requirement** in conversation | The user described what they want in natural language |

If none of these exist, stop — ask the user to describe what they want built before continuing.

## Format detection

After locating the source, detect its format:

| Format | Signals |
|--------|---------|
| **BDD** | Contains "Scenario", "Given / When / Then", "Preconditions", "Expected Results" |
| **User Story** | Contains "As a ... I want ... So that ..." or similar role-feature-benefit pattern |
| **PRD / Spec** | Structured document with sections like Goals, Requirements, Acceptance Criteria, Out of Scope |
| **Issue / Bug Report** | Contains "Steps to reproduce", "Expected behavior", "Actual behavior", or issue-like headers |
| **Free-form text** | None of the above — plain natural language description |

## Normalize

Regardless of format, extract or infer these fields into the **RequirementArtifact** structure:

| Field | Required? | How to extract |
|-------|-----------|----------------|
| **Feature / Goal** | Always | BDD: title/H1. User Story: the "I want" part. PRD: goal section. Issue: title. Free-form: first sentence or summary. |
| **Scenarios** | If available | BDD: complete Scenario blocks (name + Preconditions + Actions + Expected Results). User Story/PRD: extract acceptance criteria as implicit scenarios. Issue: steps-to-reproduce as scenario. Free-form: infer from text when enough detail exists; mark as `∅ to be inferred by plan-agent` only when truly insufficient. |
| **Expected Results** | If available | BDD: individual assertions per Scenario. PRD: acceptance criteria items. Issue: "Expected behavior" section. Free-form: infer concrete assertions from the text when possible (e.g. "persist across sessions" → "after reload, theme remains"). Mark as `∅ to be inferred by plan-agent` only when the text is too vague. |
| **Preconditions** | Optional | Any setup or state needed before the feature works. BDD: explicit. Others: infer from context. |
| **Error Paths** | Optional | Failure scenarios and expected behavior. BDD: explicit. Others: infer if mentioned. |
| **Scope** | If available | In-scope / out-of-scope boundaries. PRD: usually explicit. Others: infer from context. |

**Critical rules:**
- When BDD Scenarios exist, preserve the **complete blocks** including Actions. Do NOT flatten them into a summary. The Actions are essential for E2E execution.
- When no structured scenarios exist, **attempt to infer** Scenarios and Expected Results from the free-form text. Only mark as `∅ (to be inferred by plan-agent)` when the text genuinely lacks enough detail to extract concrete assertions. If you can infer "when X, then Y" from the user's description, do it — that's higher fidelity than deferring to the plan-agent.

## Validate

| Condition | Action if failed |
|-----------|-----------------|
| Feature / Goal is present and concrete | Surface to user — can't proceed without knowing what to build |
| At least one Scenario **or** enough detail for plan-agent to infer acceptance criteria | Surface to user if the requirement is too vague to act on |
| Expected results are concrete (not "works correctly") — only when present | Note vague results; plan-agent will refine during planning |

## Output format

Keep this structured summary in your context (do not write to disk). The shape is identical regardless of source format — downstream steps don't know or care where the requirement came from.

```
# RequirementArtifact

## Source
- Format: [BDD | User Story | PRD | Issue | Free-form]
- Path: [file path, or "conversation"]
- Confidence: [high | medium | low — how well the format maps to our structure]

## Feature
[One-line description of what to build]

## Scope
- In scope: [...]
- Out of scope: [...] (if defined)

## Scenarios (for E2E verification — pass complete blocks to e2e-runner)
### Scenario 1: [description]
- **Preconditions:** [...]
- **Actions:** [...]
- **Expected Results:** [...]

[... more scenarios, or "∅ to be inferred by plan-agent"]

## Expected Results (for functional testing — individual assertions)
- Scenario 1: [result 1], [result 2]
[... or "∅ to be inferred by plan-agent"]

## Preconditions
[... or "none specified"]

## Error Paths
[... or "none specified — plan-agent to consider"]
```

This artifact becomes the **single source of truth** for all downstream steps:
- **Step 2** (plan-agent) receives it to produce a phased plan; if Scenarios are `∅`, the plan-agent infers acceptance criteria.
- **Step 5** (functional-tester) uses Expected Results for assertion-level verification.
- **Step 6** (e2e-runner) uses complete Scenarios for journey-level verification.
