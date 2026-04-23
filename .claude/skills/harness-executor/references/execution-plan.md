# Execution Plan Template

> **Prerequisite**: Read `PLANS.md` in full before using this template.

For medium/complex tasks, create an execution plan at `docs/exec-plans/{task-name}.md` using this template.

## Template

```markdown
# Execution Plan: {task-name}

## Objective
{What we're building/fixing — one clear sentence, ≤50 chars}

## Invariants
Rules derived from AGENTS.md and docs/ARCHITECTURE.md that apply across ALL phases.

- {dependency direction constraint, e.g. "api → model only, never reverse"}
- {test coverage minimum, e.g. "≥ 80% for changed files"}
- {forbidden zone, e.g. "don't touch auth module"}
- {style/pattern constraint, e.g. "match existing error handling pattern"}

## Scope
### DO
- {what this task covers}

### DON'T
- {what this task explicitly excludes}

## Done-when
### Acceptance Criteria
- Given {user context}, When {user action}, Then {observable outcome}
- Given {user context}, When {user action}, Then {observable outcome}

### Technical Checks
- [ ] {machine-checkable condition 1}
- [ ] {machine-checkable condition 2}

## Phases

### Phase 1: {name} — Layer {N} ({layer-name})
**Pre:** {what must be true before starting — for Phase 1, usually "clean working tree"}
**Actions:**
  - {specific file change or creation}
  - {specific file change or creation}
**Forbidden:** {file paths or patterns this phase must NOT touch}
**Post:** {machine-checkable condition — command, test, or lint that passes}

### Phase 2: {name} — Layer {N} ({layer-name})
**Pre:** {must match Phase 1 Post}
**Actions:**
  - {specific file change or creation}
**Forbidden:** {file paths or patterns this phase must NOT touch}
**Post:** {machine-checkable condition}

### Phase N: Verify — E2E Tests (optional — see PLANS.md §10 for decision criteria)
**Pre:** {must match previous functional phase Post}
**Actions:**
  - Write E2E tests based on Acceptance Criteria in Done-when
**Forbidden:** Do not modify functional code
**Post:** E2E tests runnable, all pass

### Phase N+1: Validate
**Pre:** {must match previous phase Post}
**Actions:** None — run validation only
**Forbidden:** Do not modify any code
**Post:** build ✓, lint-deps ✓, lint-quality ✓, test ✓, verify ✓

## Rollback Plan
{Branch name + specific files/commits to revert. Not "revert the changes".}

## Change Log
| Session | Phase | Action | Status |
|---------|-------|--------|--------|
|         |       |        |        |
```

## Approval Process

1. Write the plan file
2. Present summary to human: objective, scope, risk level
3. **Wait for explicit approval** — do not proceed until human confirms
4. If human requests changes → update plan, re-present
5. If human rejects → exit with code 3

## Plan Quality Checklist

Before presenting for approval, run the **PLANS.md Self-Check** (section 9):

- [ ] Every phase has exactly one layer scope
- [ ] Pre/Post chain has no gaps (each phase's Post = next phase's Pre)
- [ ] Invariants are derived from project files (AGENTS.md, ARCHITECTURE.md), not guessed
- [ ] Forbidden lists are specific (file paths/patterns, not vague descriptions)
- [ ] Post conditions are machine-checkable (commands, tests, lint — not opinions)
- [ ] No speculative phases ("cleanup", "improvement", "future-proofing")
- [ ] Phase count is minimal (could a senior engineer do it in fewer steps?)
- [ ] Every Action traces to the user's original request
- [ ] Rollback is concrete (branch name, specific files to revert)
- [ ] Objective is ≤50 chars and unambiguous
- [ ] Scope DON'T list is non-empty (every task should have explicit exclusions)

## Drift Detection

After each phase completes, verify:

1. **Scope check**: `git diff --name-only HEAD~1` — all changed files within Scope DO?
2. **Forbidden check**: changed files match any Forbidden pattern? → STOP if yes
3. **Post check**: the phase's Post condition command passes?
4. **Invariant check**: Invariants still hold (e.g., `lint-deps` passes)?

If any check fails, the phase is considered FAILED regardless of whether the code "works."
