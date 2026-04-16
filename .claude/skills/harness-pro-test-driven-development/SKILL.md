---
name: harness-pro-test-driven-development
description: >
  Enforce TDD discipline: write tests before implementation code. Use this skill whenever:
  implementing any feature or bugfix, before writing implementation code. Also trigger when
  the user says "implement this", "write code for", "fix this bug", "add this feature", or
  any time you're about to write production code — the test must come first. Even if the user
  doesn't mention testing, this skill ensures correctness by requiring RED→GREEN→REFACTOR.
  This skill is invoked BY execute-task during implementation — you don't typically invoke
  it directly.
---

# Test-Driven Development Skill

You are implementing code using strict TDD discipline. Every change goes through RED → GREEN → REFACTOR.

## Iron Law

**No production code without a failing test first.**

The test defines what "done" looks like before you start coding. Without it, you're guessing.

## The Cycle

### RED — Write a Failing Test

Write a test that captures the expected behavior from the plan's Change entry. Run it — it must fail.

The test should:
- Express the behavior you want, not the implementation you imagine
- Have a clear name that describes the scenario
- Cover one behavioral unit (not everything at once)
- Fail for the right reason (not a setup error, but because the behavior doesn't exist yet)

If the test fails for the wrong reason (import error, missing fixture), fix the test setup. The RED phase proves your test can detect the absence of the behavior.

### GREEN — Write Minimum Code to Pass

Write the simplest code that makes the test pass. Nothing more.

The goal: get from red to green as directly as possible. Don't design for the future, don't add error handling the test doesn't require, don't abstract prematurely.

Ask: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### REFACTOR — Clean Up Within Scope

Refactor only what you just wrote. If the refactoring touches files beyond the current Change entry, stop — that's scope creep.

Safe refactoring:
- Extract duplicated logic within the same Change
- Improve naming within the same Change
- Simplify control flow within the same Change

Not safe:
- Refactoring adjacent code you didn't write
- Creating abstractions for code used only once
- Changing patterns in files beyond the current Change

After refactoring, re-run tests. Green? Good. Move on.

## Test Quality

### Good Tests

- Test behavior, not implementation
- Have descriptive names: `test_returns_error_when_currency_is_unsupported`
- Are independent — no shared mutable state between tests
- Cover edge cases: empty input, boundary values, error conditions
- Integration tests for API boundaries and data layer interactions

### Bad Tests

- Test private methods or internal structure
- Are trivially passing (`expect(true).toBe(true)`)
- Depend on execution order
- Mock everything — integration surface goes untested
- Only test the happy path

## Test Types by Layer

| Code Layer | Test Type | Focus |
|------------|-----------|-------|
| Pure functions / utilities | Unit | Logic correctness, edge cases |
| Business logic | Unit + Integration | Behavior + dependency interaction |
| API endpoints | Integration | Request/response contract, error handling |
| Data access | Integration | Actual database queries, migrations |

When in doubt, prefer integration tests for boundary code and unit tests for pure logic.

## When This Doesn't Apply

TDD is suspended only for:
- One-time scripts that will be thrown away
- Exploratory prototyping where the interface is unknown
- Documentation or configuration changes

If you're unsure, err on the side of writing the test first.

## Workflow Summary

```
Read the Change entry from the plan
        ↓
RED: Write test for expected behavior → run → must fail
        ↓
GREEN: Write minimum code to pass → run → must pass
        ↓
REFACTOR: Clean up within scope → run → must still pass
        ↓
Next Change entry
```
