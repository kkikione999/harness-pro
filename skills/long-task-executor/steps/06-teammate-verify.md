# Step 6 — Teammate Verification

Goal: get an independent confirmation that the work actually does what the user wanted, both at the test-suite level and at the user-experience level.

## Why a separate teammate

The worker wrote the code. The reviewer audited the code. Neither has run the system end-to-end. The teammate is the first agent in the pipeline whose job is "be the user, not the author." That perspective catches a different category of bugs.

## How to spawn

Use `Agent` with `subagent_type: "teammate"`. Spawn prompt should include:

- **Approved restatement** (Goal + Done when conditions, especially)
- **Plan file path** — so the teammate knows what was supposed to happen
- **Diff or list of changed files** — so the teammate knows where to look
- **Test command(s)** — extracted in Step 1, e.g. `pnpm test`, `pytest`, `go test ./...`
- **Run instructions** — how to start the system if E2E requires it (e.g. `pnpm dev`, `make run`)

Example:

```
You are a teammate sub-agent. Load ~/.claude/agents/teammate.md.

# Approved requirement
[paste restatement]

# What was changed
[paste diff summary or list of files]

# How to run tests
pnpm test

# How to run the system for E2E
pnpm dev  (starts on http://localhost:3000)

# Verification checklist (from Done when)
1. [first done-when condition]
2. [second done-when condition]
3. [third done-when condition]

Run the tests. Then perform user-perspective E2E verification:
walk through the feature as a user would, confirm each Done-when
condition holds, and report PASS or FAIL with evidence.
```

## What the teammate returns

A structured report:
- **Test result** — pass / fail, with output excerpt if failures
- **E2E verification** — for each Done-when condition: PASS / FAIL with evidence (what the teammate did, what they observed)
- **Surprises** — anything that worked but felt wrong from a user's perspective (slow, confusing, edge cases)

## What you do with it

| Teammate result | Next action |
|-----------------|-------------|
| Tests PASS, all E2E checks PASS | Continue to Step 7 (commit gate) |
| Tests FAIL | Loop back to Step 5 with the test failures as reviewer-style findings |
| Tests PASS but E2E FAIL | Loop back to Step 5 — the code "works" but doesn't deliver the user goal |
| Surprises but no failures | Note them, continue, surface them to the user when reporting completion |

## E2E specifics

What "user-perspective E2E verification" means depends on the project — see `references/e2e-verification.md` for the long form. Short version:

- **Web app**: open the page, click the buttons a user would click, look for the right output
- **CLI**: run the actual command with the actual flags a user would run, check exit code and output
- **Library**: import it from a fresh script and exercise the public API the way a consumer would
- **Backend service**: hit the endpoints with the kind of payloads real clients send

The point is to verify the *user-facing contract*, not just internal correctness.

## Skip rules

There are none. Even for "small" changes, the teammate step protects against the most common failure mode: tests pass but the feature doesn't actually do what the user asked. If the user has explicitly said "skip verification, I'll check it myself," fine — but record that in the final report.
