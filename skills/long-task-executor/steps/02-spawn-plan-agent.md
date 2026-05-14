# Step 2 — Spawn the plan-agent

Goal: produce a phased plan without writing any production code yourself.

## Trigger

RequirementArtifact loaded in Step 1. Not before.

## How to spawn

Use the `Agent` tool with `subagent_type: "plan-agent"`. The spawn prompt should contain:

- **RequirementArtifact** — the full normalized artifact from Step 1 (including format, source, and confidence level)
- **Project root** — absolute path
- **CLAUDE.md location** (if found) — so the plan-agent reads the same conventions you did
- **Tech stack & test command** — what you discovered in Step 1
- **Constraints from the user** — any deadlines, must-not-touch files, performance budgets, etc.

Example spawn prompt skeleton:

```
You are the plan-agent. Load the agent definition at ./agents/plan-agent.md (plugin-bundled).

# Requirement (normalized from [format])
[paste the RequirementArtifact]

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

## Handling missing acceptance criteria

When the RequirementArtifact has `∅ to be inferred by plan-agent` for Scenarios or Expected Results, the spawn prompt must include an additional instruction:

```
# Acceptance Criteria Inference

The requirement does not include structured Scenarios or Expected Results.
As part of your plan, you MUST:

1. Infer concrete, testable Done-when conditions from the requirement text.
2. Write them as numbered assertions in the plan's "Acceptance Criteria" section.
3. Each assertion must be:
   - Specific enough to verify with a test or manual check
   - Written in "X should Y" or "when A, then B" form
   - Traceable to a specific part of the requirement

These inferred conditions become the acceptance criteria for functional-test
(Step 5) and E2E (Step 6). The reviewer (Step 4) will also check that the
implementation satisfies them.

Do NOT fabricate requirements that aren't implied by the original text.
Infer only what is necessary to make the stated goals verifiable.
```

When BDD Scenarios DO exist, do NOT include this instruction — the BDD Scenarios ARE the acceptance criteria. The plan-agent should reference them, not redefine them.

## What you receive back

A path to a plan file (the plan-agent writes it to disk so it survives across sub-agent boundaries). The plan should contain numbered phases, each with:
- Phase name
- Files to touch
- Post-conditions (how you know the phase is done)
- Dependencies on other phases (or "none")
- **Acceptance Criteria** (inferred if not provided in BDD — only when applicable)

## What to do with the plan

Read it yourself. Verify:
- Every acceptance criterion from the RequirementArtifact is covered (explicit BDD Scenarios or inferred Done-when)
- Out-of-scope items don't appear in any phase
- Phase dependencies form a DAG, not a cycle
- Inferred acceptance criteria are concrete and testable (not "works correctly")

If the plan looks wrong, **don't fix it yourself** — re-spawn the plan-agent with feedback. The plan-agent owns plan content; you own plan acceptance.

## Skip rules

For genuinely trivial requests ("rename this variable everywhere"), you may skip the plan-agent and dispatch a worker directly. The bar for skipping: a single phase, single file, no review needed beyond a basic sanity check. When in doubt, plan.
