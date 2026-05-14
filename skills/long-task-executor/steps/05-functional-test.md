# Step 5 — Functional Testing

Goal: verify that each individual assertion from the requirement is satisfied by the implementation, before running expensive E2E journeys.

## Why functional testing comes before E2E

- **Cheaper**: Unit/integration tests run in seconds; E2E may take minutes
- **Faster feedback**: Catch function-level bugs early, before spinning up browsers/dev servers
- **Clearer diagnosis**: When a function is broken, the fix is usually obvious. When a journey is broken, the root cause could be anywhere in the chain.

## What to verify — depends on the source

| Requirement format | What functional-tester checks |
|--------------------|-------------------------------|
| **BDD with Scenarios** | Each Expected Result from each Scenario — individually, with evidence |
| **PRD with Acceptance Criteria** | Each AC item — verified against the implementation |
| **Free-form / inferred AC** | Each Done-when condition from the plan-agent's inferred Acceptance Criteria section |
| **Bug report / Issue** | That the reported bug is fixed (steps-to-reproduce no longer cause the issue) |

## How to spawn

Use `Agent` with `subagent_type: "functional-tester"`. Spawn prompt should include:

- **RequirementArtifact** — the normalized requirement (with format noted)
- **Plan file path** — what was supposed to happen (including inferred AC if applicable)
- **Diff or list of changed files** — where to focus
- **Test command(s)** — e.g. `pnpm test`, `pytest`, `go test ./...`
- **Verification target** — explicit: "verify each Expected Result" or "verify each inferred Done-when condition"

Example (BDD source):

```
You are a functional-tester sub-agent. Load the agent definition at ./agents/functional-tester.md (plugin-bundled).

# Requirement (BDD format)
[paste RequirementArtifact — Scenarios and Expected Results sections]

# What was changed
[paste diff summary or list of files]

# How to run tests
pnpm test

Verify each Expected Result from the BDD document independently.
Report PASS or FAIL with evidence.
```

Example (free-form source with inferred AC):

```
You are a functional-tester sub-agent. Load the agent definition at ./agents/functional-tester.md (plugin-bundled).

# Requirement (free-form — inferred acceptance criteria)
The user requested: [original text]

The plan-agent inferred these acceptance criteria:
[paste inferred AC from the plan]

# What was changed
[paste diff summary or list of files]

# How to run tests
pnpm test

Verify each inferred acceptance criterion independently.
Report PASS or FAIL with evidence.
```

## What the functional-tester returns

A structured report:
- **Test result** — pass / fail, with output excerpt if failures
- **Functional verification** — for each assertion (BDD Expected Result, AC item, or inferred Done-when): PASS / FAIL / DEFERRED_TO_E2E with evidence
- **Deferred items** — assertions that require E2E to verify (e.g. "user receives email in inbox")

## What you do with it

| functional-tester result | Next action |
|--------------------------|-------------|
| Tests PASS, all assertions PASS | Continue to Step 6 (E2E verification) |
| Tests FAIL | Loop back to Step 4 with the test failures as reviewer-style findings |
| Some assertions DEFERRED | Note them, continue to E2E — the e2e-runner will verify |

## Skip rules

For "pure refactor (no behavior change)" where the requirement has no new behavior:
- Run the test suite to confirm nothing broke
- Skip individual assertion verification (there aren't any new ones)
- Proceed to E2E if the project has existing E2E tests
