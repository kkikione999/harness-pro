---
name: harness-pro-systematic-debugging
description: >
  Investigate root causes before proposing fixes. Use this skill whenever: you encounter a bug,
  test failure, unexpected behavior, error message, or any situation where code doesn't behave
  as expected. Also trigger when the user says "this is broken", "why does this fail", "fix this
  bug", "debug this", or any time you're tempted to guess at a fix. Iron law: NO FIXES WITHOUT
  ROOT CAUSE INVESTIGATION FIRST. This skill is invoked BY execute-task when a test fails or a
  bug is discovered during implementation.
---

# Systematic Debugging Skill

You are investigating why something doesn't work as expected. Your job is to find the root cause before writing any fix.

## Iron Law

**No fixes without root cause investigation first.**

A fix without understanding is a guess. Guesses sometimes work, but they hide the real problem and create new ones. You must understand WHY before you change anything.

## Debugging Process

### Step 1: Read the Error

Start with the exact error message or observed behavior:
- Copy the full error message, stack trace, or failing test output
- Identify the exact location (file, line, function)
- Note the error type: compilation error, runtime crash, assertion failure, wrong output, performance issue

Do not skim. Read every word of the error message. Error messages often tell you exactly what's wrong.

### Step 2: Reproduce

Can you reproduce the issue reliably?
- Run the failing test or scenario
- If intermittent: note the conditions when it occurs
- If you can't reproduce: the investigation isn't done yet

A non-reproducible bug is an unsolved bug.

### Step 3: Trace the Data Flow

Follow the data from input to the point of failure:
- What value goes in?
- What transformation happens at each step?
- Where does the actual value diverge from the expected value?

Read the code along the path. Don't skip steps based on assumption.

### Step 4: Form Hypotheses

Based on the data flow trace, propose specific hypotheses:

> "The function receives null because the upstream filter removes the field"
> "The regex doesn't match because the input has a Unicode character"
> "The API returns 404 because the ID is URL-encoded twice"

Each hypothesis must be falsifiable — there must be a way to check if it's wrong.

### Step 5: Test Hypotheses

For each hypothesis:
- What would be true if this hypothesis is correct?
- Check that specific thing (read code, add logging, run a targeted test)
- If confirmed → root cause found
- If refuted → move to next hypothesis

### Step 6: Root Cause → Fix

Once you've confirmed the root cause:
- The fix should address the root cause directly, not the symptom
- Write a test that reproduces the bug (goes through test-driven-development RED)
- Implement the fix (GREEN)
- Verify the original failing test now passes

## Common Patterns

| Symptom | Likely Root Cause | Check |
|---------|-------------------|-------|
| Null pointer | Missing null check upstream | Trace where the value originates |
| Wrong type | Implicit coercion or missing validation | Check the type at each transformation step |
| Off-by-one | Incorrect boundary condition | Check loop bounds, array indexing |
| Flaky test | Shared mutable state, timing, or external dependency | Check test isolation |
| "Works on my machine" | Environment difference | Check config, env vars, file paths |
| Regression | Recent change broke assumption | Check recent commits touching the same code |

## Escalation

Escalate to the user when:
- The root cause is in a dependency you can't modify
- The fix requires an architectural change beyond the current plan's scope
- Multiple unrelated failures suggest a systemic issue

Do NOT escalate for:
- Normal bugs that can be fixed within the current Change entry
- Test failures from incorrect test assumptions (fix the test)
- Plan deviations that can be handled locally

## What NOT to Do

- Do NOT change code hoping it fixes the problem (guess-driven debugging)
- Do NOT skip the reproduction step
- Do NOT assume the error message is lying — it's usually right
- Do NOT fix the symptom without understanding the cause
- Do NOT say "this should work" without evidence that it does

## Workflow Summary

```
Observe: error / failure / unexpected behavior
        ↓
Read the error completely → Reproduce reliably
        ↓
Trace data flow from input to failure point
        ↓
Form specific, falsifiable hypotheses
        ↓
Test hypotheses one by one → confirm root cause
        ↓
Fix the root cause (via test-driven-development: RED → GREEN → REFACTOR)
        ↓
Verify original failure is resolved
```
