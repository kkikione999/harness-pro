# Step 1 — Load Requirement

Goal: load the confirmed requirement document and extract context for the plan-agent.

## Locate the document

1. Check `docs/feature/` for a `.md` file (BDD document from `bdd-product-craft`)
2. If none, check the conversation for a confirmed requirement artifact
3. If neither exists, stop — ask the user to confirm requirements first

## Extract

Read the document and extract:

| Field | How to extract |
|-------|----------------|
| **Feature / Goal** | Title or H1 heading |
| **Requirements** | Scenarios, user stories, acceptance criteria |
| **Preconditions** | Setup or state needed before implementation |
| **Expected Results** | What "done" looks like (concrete, verifiable) |
| **Error Paths** | Failure scenarios and expected behavior |

## Validate

- At least one requirement exists
- Expected results are concrete (not "works correctly")
- Error paths are defined or explicitly noted as N/A

If validation fails, surface to the user.

## Output

Keep a structured summary in your context (do not write to disk):

```
# Requirement Summary

Feature: [Name]

## Requirements
1. [Requirement] — happy path
   - Preconditions: [...]
   - Expected: [...]

2. [Requirement] — error path
   - Preconditions: [...]
   - Expected: [...]
```

This becomes the **approved requirement** passed to the plan-agent in Step 2.
