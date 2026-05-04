# Step 3 — Spawn the plan-agent

Goal: produce a phased plan without writing any production code yourself.

## Trigger

Approval received in Step 2. Not before.

## How to spawn

Use the `Agent` tool with `subagent_type: "plan-agent"`. The spawn prompt should contain:

- **Approved restatement** — the exact Goal / In scope / Out of scope / Done when block from Step 2
- **Project root** — absolute path
- **CLAUDE.md location** (if found) — so the plan-agent reads the same conventions you did
- **Tech stack & test command** — what you discovered in Step 1
- **Constraints from the user** — any deadlines, must-not-touch files, performance budgets, etc.

Example spawn prompt skeleton:

```
You are the plan-agent. Load the agent definition at ./agents/plan-agent.md (plugin-bundled).

# Approved requirement
[paste the restatement block]

# Project context
- Root: /path/to/project
- CLAUDE.md: /path/to/project/CLAUDE.md
- Stack: TypeScript / Node / Vitest
- Test command: pnpm test

# Constraints
- Don't touch the legacy `src/old-billing/` directory
- Must work without changing the public API surface

Produce a plan as specified in your agent definition. Return the plan path.
```

## What you receive back

A path to a plan file (the plan-agent writes it to disk so it survives across sub-agent boundaries). The plan should contain numbered phases, each with:
- Phase name
- Files to touch
- Post-conditions (how you know the phase is done)
- Dependencies on other phases (or "none")

## What to do with the plan

Read it yourself. Verify:
- Every "Done when" condition from the approved restatement is covered
- Out-of-scope items don't appear in any phase
- Phase dependencies form a DAG, not a cycle

If the plan looks wrong, **don't fix it yourself** — re-spawn the plan-agent with feedback. The plan-agent owns plan content; you own plan acceptance.

## Skip rules

For genuinely trivial requests ("rename this variable everywhere"), you may skip the plan-agent and dispatch a worker directly. The bar for skipping: a single phase, single file, no review needed beyond a basic sanity check. When in doubt, plan.
