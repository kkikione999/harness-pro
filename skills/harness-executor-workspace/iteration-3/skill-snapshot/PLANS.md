# PLANS.md — Plan Creation Behavioral Guidelines

> **MANDATORY**: Read this document in full before creating ANY execution plan or Task Contract.
> These guidelines reduce common LLM coding mistakes during the planning phase.
> Merge with project-specific instructions from AGENTS.md and docs/ as needed.

**Tradeoff**: These guidelines bias toward caution over speed. For trivial tasks, use judgment.

---

## 1. Think Before Planning

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before writing a plan:
- State your assumptions explicitly. If uncertain, ask the user.
- If multiple interpretations of the task exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

**Applied to planning:**
- If the task description is vague, list 2-3 possible interpretations and ask.
- If you're unsure which layer a change belongs to, say so and propose checking ARCHITECTURE.md.
- If the task seems to violate a project constraint, flag it before planning.

## 2. Simplicity First

**Minimum phases that solve the problem. Nothing speculative.**

- No phases beyond what the task requires.
- No "while we're here" refactoring phases.
- No abstractions or generalizations that weren't requested.
- No error handling phases for impossible scenarios.
- If a plan has 6 phases and could be 3, rewrite it.

Ask yourself: "Would a senior engineer say this plan is overcomplicated?" If yes, simplify.

**Applied to planning:**
- One layer per phase — don't bundle model + service changes into one phase.
- Don't add "cleanup" or "improvement" phases unless explicitly asked.
- Don't plan for future extensibility. Plan for the current task only.

## 3. Surgical Scope

**Each phase touches only what it must. Define hard boundaries.**

When defining phases:
- Every Forbidden entry should trace directly to "this phase doesn't need it."
- Don't add "nice-to-have" items to the Actions list.
- If a phase needs to touch >5 files, the phase is probably too broad — split it.
- Match existing code patterns even if you'd design them differently.

The test: Every Action in every phase should trace directly to the user's request. If it doesn't, remove it.

**Applied to planning:**
```
WRONG:
  Phase 2: "Refactor user service and add email validation"
  → Two concerns, unclear boundary

RIGHT:
  Phase 2: "Add email validation logic to user service"
  Phase 3: "Refactor user service" (only if explicitly requested)
```

## 4. Goal-Driven Phases

**Define verifiable Post conditions. Not descriptions — checks.**

Transform vague phases into verifiable ones:
- "Add validation" → Post: `make test` passes with new validation test cases
- "Fix the bug" → Post: reproduction test passes
- "Refactor X" → Post: same tests pass before and after, no behavioral change

For every phase, the Post condition must be:
1. **Machine-checkable** — a command, a test, a lint rule, not a human opinion
2. **Unambiguous** — pass or fail, no gray area
3. **Minimal** — only checks what this phase changed, not the whole project

```
WRONG Post: "The feature works correctly"
RIGHT Post: "`POST /register` returns `email_verification_status` field, test covers it"
```

## 5. Pre/Post Chain Integrity

**Each phase's Post must be the next phase's Pre.**

The chain must be gapless:
```
Phase 1 Post: "Email field exists in User model, migration file created"
  = Phase 2 Pre: "User model has Email field"
Phase 2 Post: "Validation logic in user_service, unit tests pass"
  = Phase 3 Pre: "Validation logic exists in service layer"
```

If a Pre condition can't be satisfied by the previous phase's Post, the plan has a gap. Fix the plan, don't hope the executor figures it out.

## 6. Invariant Extraction

**Derive Invariants from project rules, not from guesswork.**

Before writing phases:
1. Read `AGENTS.md` → extract layer rules and build commands
2. Read `docs/ARCHITECTURE.md` → extract dependency direction
3. Combine into Invariants that apply across ALL phases

Common invariants:
- Dependency direction (e.g., "api → model only, never reverse")
- Test coverage minimum (e.g., "≥ 80% for changed files")
- Forbidden zones (e.g., "don't touch auth module")
- Style consistency (e.g., "match existing error handling pattern")

## 7. Layer-Ordered Phasing

**Phases run from low layer to high layer. Never skip or reverse.**

```
Layer 1 (model/schema) → Layer 2 (repository/data) → Layer 3 (service/logic) → Layer 4 (api/handler) → Layer 5 (ui/transport)
```

Reasoning:
- Lower layers have no dependencies on higher layers.
- Higher layers depend on lower layers.
- Building bottom-up means each phase's Pre is naturally satisfied.
- This is the single most effective anti-drift mechanism.

If a task only touches high layers (e.g., API change only), skip lower phases — but never reverse the order.

## 8. Forbidden Over DO

**Forbidden list is more important than Actions list.**

DO describes what should happen. Forbidden describes what must NOT happen.

Drift detection checks Forbidden, not DO. A phase that completes its Actions but also touches a Forbidden file has FAILED, even if the code "works."

```
Phase 2 Actions:  Modify user_service.go
Phase 2 Forbidden: Don't touch handlers/, routes/, models/

Drift check:
  git diff --name-only HEAD~1 → [user_service.go, handlers/auth.go]
  handlers/auth.go matches Forbidden → STOP. Phase failed.
```

## 10. Verify Phase Decision

**E2E verification is a deliverable, not a validation step. If it needs code, it needs a phase.**

### When to include a Verify Phase

| Scenario | Decision |
|----------|----------|
| Task changes user-visible behavior and no E2E test covers it | **Must include** Verify Phase |
| Existing E2E tests already cover the changed behavior | Skip — use existing tests in Validate |
| Internal refactor, user behavior unchanged | Skip |
| Framework/tooling change with no user-facing impact | Skip |

Judgment call: If any Done-when item describes a user action (not a technical output), it needs E2E coverage. If that coverage doesn't exist yet, you need a Verify Phase.

### How to write Acceptance Criteria

Done-when must contain two layers:

**Acceptance Criteria** (user perspective — this is the E2E test spec):
```
- Given {user context}, When {user action}, Then {observable outcome}
- Given {user context}, When {user action}, Then {observable outcome}
```

**Technical Checks** (machine-verifiable conditions):
```
- [ ] {command or test passes}
- [ ] {command or test passes}
```

Acceptance Criteria feed directly into the Verify Phase. If you write them well, the Verify Phase agent knows exactly what to test. If you can't write them, the task objective is too vague — go back to section 1.

### Verify Phase positioning

Always the last functional phase, before Validate:
```
Phase 1..N: Functional phases (layer-ordered)
Phase N+1:  Verify (write E2E tests from Acceptance Criteria) — optional
Phase N+2:  Validate (run full pipeline, including E2E from Verify Phase)
```

## 9. Plan Self-Check

Before presenting a plan for approval, verify:

- [ ] Every phase has exactly one layer scope
- [ ] Pre/Post chain has no gaps
- [ ] Invariants are derived from project files, not guessed
- [ ] Forbidden lists are specific (file paths, not vague descriptions)
- [ ] Post conditions are machine-checkable (commands, not opinions)
- [ ] No speculative phases ("cleanup", "improvement", "future-proofing")
- [ ] Phase count is minimal (could a senior engineer do it in fewer steps?)
- [ ] Every Action traces to the user's original request
- [ ] Rollback is concrete (branch name, specific files to revert)

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, plans are approved on first submission, and phases complete without scope creep.
