---
name: long-task-executor
description: >
  Execute large, multi-phase implementation tasks from any confirmed requirement.
  Accepts BDD documents (docs/feature/*.md), PRDs, user stories, issue descriptions,
  file paths, or free-form conversation text — automatically detects format and
  normalizes to a unified internal structure.
  Orchestrates the full implementation pipeline:
  load → plan → build → review → functional-test → e2e-test → commit.
  Trigger on phrases like: "start implementing", "build this feature", "code it up",
  "let's develop this", "proceed to implementation", "implement the requirements in X",
  "build what we discussed", "make this happen".
  Always prefer this skill for tasks that span multiple files or require phased execution.
  If a BDD document exists in docs/feature/, load it; if a file path is given, load that;
  otherwise extract the requirement from the conversation.
---

# Long-Task Executor

> **You are the coordinator. You do NOT write production code yourself.**
> Your job is to **spawn sub-agents one step at a time** and route their outputs to the next step.
> You do NOT execute the full pipeline in one go. Each step is a separate sub-agent spawn.
>
> Orchestrate five sub-agents — `plan-agent`, `worker`, `reviewer`, `functional-tester`, `e2e-runner`
> — until implementation is complete.

## Checklist

```
1. Load requirement      → Detect format (BDD / PRD / User Story / Issue / Free-form),
                           normalize to RequirementArtifact
2. Spawn plan-agent      → Technical phased plan (references requirement, infers
                           acceptance criteria if not provided)
3. Dispatch workers      → Parallel for independent phases
4. Review loop           → reviewer → fix → reviewer → PASS
5. Functional test       → Verify each Expected Result independently (or inferred AC
                           from plan)
6. E2E verify            → Execute Scenarios as user journeys (or simplified critical-path
                           E2E based on inferred goals)
7. Conditional commit    → Git commit if clean, tests pass, no secrets
```

## Requirement Input Formats

The executor accepts any of these. Step 1 auto-detects the format and normalizes:

| Format | Source | How it enters |
|--------|--------|---------------|
| **BDD document** | `docs/feature/*.md` (from bdd-product-craft) | Auto-detected by file presence |
| **User-provided file** | Any path the user specifies | User says "implement X" or "use this file" |
| **PRD / Spec** | File or conversation | Detected by structure (Goals, Requirements, AC sections) |
| **User Story** | File or conversation | Detected by "As a... I want... So that..." pattern |
| **Issue / Bug Report** | File or conversation | Detected by steps-to-reproduce / expected-vs-actual |
| **Free-form text** | Conversation | Default — whatever the user described in natural language |

All formats are normalized to a **RequirementArtifact** in Step 1. Downstream steps consume this unified structure.

## Acceptance Criteria Strategy

| Source has | Strategy |
|------------|----------|
| Full BDD Scenarios with Expected Results | Use as-is — BDD Scenarios ARE the acceptance criteria |
| Partial structure (e.g. PRD with AC items) | Normalize AC items into lightweight scenarios for E2E |
| No structured criteria (free-form text) | plan-agent **infers** concrete Done-when conditions from the requirement text. These inferred conditions serve as acceptance criteria for functional-test and E2E. |

## Spawned Sub-Agents

| Sub-Agent | Source | When | Purpose |
|-----------|--------|------|---------|
| **plan-agent** | `./agents/plan-agent.md` | Step 2 | Phased execution plan. No code. References requirement as acceptance criteria; infers criteria if missing. |
| **worker** | `./agents/worker.md` | Step 3 + fix loop | Implements one phase. Returns diff + post-conditions. |
| **reviewer** | `./agents/reviewer.md` | Step 4 | Audits code. Returns PASS/FAIL with severity notes. |
| **functional-tester** | `./agents/functional-tester.md` | Step 5 (after reviewer PASS) | Runs test suite + verifies each Expected Result or inferred AC independently. |
| **e2e-runner** | `./agents/e2e-runner.md` | Step 6 (after functional-test PASS) | Executes Scenarios as complete user journeys; or critical-path simplified E2E for inferred goals. |

## Hard Constraints

- Do NOT skip Step 1. Load and normalize the requirement before any planning.
- Do NOT re-restate requirements or ask for approval — they are already confirmed.
- When BDD Scenarios exist, they ARE the acceptance criteria — plan-agent must NOT create competing Done-when conditions.
- When no BDD Scenarios exist, the plan-agent's inferred acceptance criteria serve as the Done-when. These are the floor, not the ceiling — the reviewer may flag additional concerns.
- Do NOT cap the review-fix loop. Loop until PASS. Escalate to user if stuck.
- Do NOT skip functional testing. E2E is expensive; catch function-level bugs first.
- Do NOT auto-commit unless every gate in `references/commit-gating.md` passes.
- Do NOT write production code yourself. Single-line typo fixes only.
- Do NOT try to execute all steps in one sub-agent spawn. Each step spawns its own sub-agent. You wait for it to return, then decide the next step.

## Dispatch Strategy

| Plan shape | Strategy |
|------------|----------|
| Phases are independent | **Parallel** — one message, N Agent calls |
| Strict chain A → B → C | **Sequential** — wait for A before B |
| Mixed | **Topological layers** — parallel within layer, sequential between |

Default to sequential if unsure. See `references/parallel-execution.md`.

## Test Pipeline Flow

```
reviewer PASS
    │
    ▼
┌──────────────┐     FAIL      ┌─────────────┐
│ functional-  │──────────────►│ review-loop │
│ tester       │               │ (code bugs) │
└──────────────┘               └─────────────┘
    │ PASS
    ▼
┌──────────────┐     FAIL      ┌─────────────┐
│ e2e-runner   │──────────────►│ e2e-fix     │
│ (journeys)   │               │ loop        │
└──────────────┘               └─────────────┘
    │ PASS
    ▼
  commit
```

**Failure routing:**
- Functional test fails → back to review-loop (code-level bug)
- E2E fails → e2e-fix loop (journey-level bug, may not need full re-review)

## References

- `references/parallel-execution.md` — dispatch strategy
- `references/review-loop.md` — reading reviewer output, crafting fix prompts
- `references/e2e-verification.md` — user-perspective E2E for this project
- `references/commit-gating.md` — auto-commit gates

## Pipeline

Confirmed requirement (any format) → `long-task-executor` loads, normalizes, and implements it.

Required agents: `plan-agent`, `worker`, `reviewer`, `functional-tester`, `e2e-runner`. If any are missing, stop at Step 1.
