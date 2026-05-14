# Step 6 — E2E Verification

Goal: confirm the system delivers the user's goal by executing complete user journeys. The source format determines the E2E strategy.

## Why E2E is separate from functional testing

Functional testing verifies "each function works." E2E verifies "the user can complete their goal." These catch different bugs:

- Function passes + Journey fails = integration bug, routing bug, state management bug
- Function fails + Journey passes = usually impossible (if functions are broken, the journey breaks)

## E2E strategy by requirement format

| Format | E2E approach |
|--------|-------------|
| **BDD with full Scenarios** | Execute each Scenario as a complete journey — Preconditions → Actions → verify Expected Results. This is the richest mode. |
| **PRD / User Story with AC** | Walk through each critical user path implied by the acceptance criteria. Focus on the main success path and any explicitly mentioned error paths. |
| **Free-form / inferred AC** | **Critical-path E2E**: the e2e-runner identifies the most important user goal(s) from the requirement and walks through them end-to-end. Not exhaustive — focuses on "can the user actually do what they asked for?" |
| **Bug report / Issue** | Reproduce the original issue scenario to confirm the fix works. Walk the exact steps-to-reproduce and verify the fix. |

## How to spawn

Use `Agent` with `subagent_type: "e2e-runner"`. Spawn prompt should include:

- **RequirementArtifact** — the normalized requirement (format + content)
- **Plan file path** — what was supposed to happen (context only, including inferred AC if applicable)
- **Diff or list of changed files** — where to focus (context only)
- **Run instructions** — how to start the system for E2E (e.g. `pnpm dev`, `make run`)
- **Project type** — web / API / CLI / library / mobile
- **E2E mode** — explicit: "full BDD journeys" or "critical-path E2E for inferred goals"

Example (BDD source):

```
You are an e2e-runner sub-agent. Load the agent definition at ./agents/e2e-runner.md (plugin-bundled).

# Requirement (BDD format)
[paste RequirementArtifact — complete Scenarios with Actions]

# What was changed
[paste diff summary or list of files]

# How to run the system for E2E
pnpm dev  (starts on http://localhost:3000)

# Project type
Web frontend

Execute each BDD Scenario as a complete user journey.
Report PASS or FAIL with evidence for each Scenario.
```

Example (free-form source with inferred AC):

```
You are an e2e-runner sub-agent. Load the agent definition at ./agents/e2e-runner.md (plugin-bundled).

# Requirement (free-form)
The user requested: [original text]

Inferred acceptance criteria:
[paste inferred AC from the plan]

# E2E mode
Critical-path E2E. Identify the main user goal(s) from the requirement above
and walk through each one end-to-end as a real user would. Focus on the happy
path; if error handling was mentioned, test that too.

# What was changed
[paste diff summary or list of files]

# How to run the system for E2E
pnpm dev

# Project type
Web frontend

Report PASS or FAIL with evidence for each journey you tested.
```

## What the e2e-runner returns

A structured report:
- **E2E verification** — for each journey: PASS / FAIL with evidence (what the e2e-runner did, what they observed)
- **Surprises** — anything that worked but felt wrong from a user's perspective

## What you do with it

| E2E-runner result | Next action |
|-------------------|------------|
| All journeys PASS | Continue to Step 7 (commit gate) |
| Any journey FAIL | Enter e2e-fix loop (see below) |
| Surprises but no failures | Note them, continue, surface to user in completion report |

## E2E-fix loop (distinct from review-fix loop)

When E2E fails but functional tests passed, the bug is likely:
- Integration issue (functions work individually but not together)
- Routing/navigation issue
- State management issue
- UI flow issue

**Do NOT send E2E failures back to the review loop.** The reviewer audits code; E2E failures are runtime journey issues. Instead:

```
e2e-runner FAIL
    │
    ▼
spawn e2e-fix-worker
    │
    ▼
re-run e2e-runner
    │
    ├─ PASS → continue
    └─ FAIL → repeat (max 3 rounds, then escalate to user)
```

**e2e-fix-worker prompt:**
```
You are a worker sub-agent. This is an E2E fix iteration.

The e2e-runner reported the following journey failure:
[paste e2e-runner failure report]

The functional tests all pass, so individual functions work.
The issue is likely integration, routing, or UI flow.

Fix exactly the reported issue. Do not make unrelated changes.
Do not refactor. Do not "improve" code that wasn't flagged.
```

## Skip rules

- **Pure refactor (no behavior change)**: confirm existing E2E tests still pass. If no existing E2E tests, note the gap and proceed.
- **Library / package with no runnable user interface**: skip browser E2E. Rely on functional-tester's consumer-script verification from Step 5.
- **No dev server or runtime available**: note the limitation, proceed to commit with a caveat that E2E was not performed.
