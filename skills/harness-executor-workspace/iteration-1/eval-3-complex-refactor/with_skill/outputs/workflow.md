# Workflow Description: Circular Dependency Refactor (UserService <-> AuthService)

This document describes the exact steps the harness-executor skill would follow for the given task.

---

## 1. Complexity Classification: COMPLEX

**Classification: Complex**

The task is classified as Complex based on three criteria from the complexity decision tree:

- **Cannot be described in one sentence without "and":** "Refactor the circular dependency between UserService and AuthService by extracting a protocol AND updating both services to depend on the protocol AND updating all call sites AND ensuring tests still pass." Multiple "and" clauses present.
- **Architecture changes required:** The task description explicitly states "structural refactoring that touches architecture." This triggers the "Architectural decision needed" escalation signal from the Dynamic Complexity Escalation table, which escalates Any to Complex.
- **New modules/artifacts introduced:** A new protocol file must be created in a different location (likely `types/` or a protocols directory at layer 0), and cross-module imports must be restructured.

This classification determines all downstream decisions: sub-agent delegation, worktree isolation, cross-review, and the full 5-step validation pipeline.

---

## 2. Steps Executed vs Skipped

| Step | Action | Reason |
|------|--------|--------|
| 1. DETECT | **Execute** | Check for AGENTS.md; if missing, invoke harness-creator then resume |
| 2. LOAD | **Execute** | Read AGENTS.md, docs/ARCHITECTURE.md, docs/DEVELOPMENT.md, harness/memory/INDEX.md |
| 3. PLAN | **Execute** | Complex tasks require a full execution plan |
| 4. APPROVE | **Execute** | Complex tasks require human approval before delegation |
| 5. EXECUTE | **Execute** | Delegate to sub-agent via worktree (complex isolation) |
| 6. VALIDATE | **Execute** | Full 5-step pipeline (structural change) |
| 7. CROSS_REVIEW | **Execute** | Complex task, different model reviews the diff |
| 8. COMPLETE | **Execute** | Git commit on worktree branch, write memory, check trajectory compilation |

No steps are skipped. Complex tasks run the full 8-step workflow.

---

## 3. Execution Plan (Full Content)

The following plan would be written to `docs/exec-plans/break-circular-dep-user-auth.md`:

```markdown
# Execution Plan: break-circular-dep-user-auth

## Objective
Break the circular dependency between services/UserService.swift and services/AuthService.swift
by extracting a protocol that decouples the two services, allowing each to depend on the
abstraction rather than on each other directly.

## Impact Scope
- `types/AuthProviding.swift` (Layer 0) — NEW FILE: protocol definition
- `services/UserService.swift` (Layer 3) — MODIFY: replace AuthService import with protocol
- `services/AuthService.swift` (Layer 3) — MODIFY: conform to protocol, remove UserService import
- `services/` (Layer 3) — potentially other call sites that instantiate or wire these together
- Tests for UserService and AuthService — may need updates to mock the protocol

## Steps

1. **Analyze the circular dependency**
   - Read services/UserService.swift to understand what it imports from AuthService
   - Read services/AuthService.swift to understand what it imports from UserService
   - Document the exact methods/properties that create the cycle

2. **Design the protocol abstraction**
   - Define a protocol (e.g., `AuthProviding`) in `types/AuthProviding.swift` (Layer 0)
   - The protocol declares only the interface that UserService needs from AuthService
   - This protocol must not import anything from Layer 3

3. **Refactor AuthService to conform to the protocol**
   - Add conformance: `AuthService: AuthProviding`
   - Remove the import of UserService from AuthService
   - If AuthService needed something from UserService, pass it as a parameter instead

4. **Refactor UserService to depend on the protocol**
   - Replace `import AuthService` with `import AuthProviding` (from types/)
   - Change concrete dependency on AuthService to the `AuthProviding` protocol
   - Use dependency injection: accept an `AuthProviding` instance in the initializer

5. **Update call sites and wiring**
   - Find all places that instantiate UserService and/or AuthService
   - Update to inject the concrete AuthService where the protocol is expected
   - Ensure no remaining circular references exist

6. **Update tests**
   - Update UserService tests to use a mock `AuthProviding` instead of real AuthService
   - Verify AuthService tests still pass with the new protocol conformance
   - Add test that verifies protocol conformance compiles correctly

## Validation
- [ ] Build passes (`swift build`)
- [ ] lint-deps passes (`./scripts/lint-deps`) — critical: new file in types/ must not import Layer 3
- [ ] lint-quality passes (`./scripts/lint-quality`)
- [ ] All tests pass (`swift test`)
- [ ] Verify passes (`python3 scripts/verify/run.py`)

## Rollback Plan
- Branch name: `refactor/break-circular-dep-user-auth`
- All changes are on the worktree branch; if validation fails and cannot be repaired,
  the worktree is discarded and the main branch is untouched
- If merged and issues found: `git revert <commit-hash>` on main

## Checkpoint After
- Save `phase-1-context-loaded` after reading all files
- Save `phase-2-plan-approved` after human approval
- Save `phase-3-execution-complete` after sub-agent finishes
- Save `phase-4-validated` after pipeline passes
- Save `phase-5-reviewed` after cross-review completes
```

---

## 4. Model Selection for Sub-Agent

**Model: opus**

The task is classified as Complex, and the model selection rules from Step 5 are:

- `haiku` — Fast execution, simple changes
- `sonnet` — Medium complexity, code generation
- `opus` — Deep reasoning, refactoring, architecture

This task is explicitly "structural refactoring that touches architecture" and requires:

1. Understanding the existing dependency graph between two coupled services
2. Designing a protocol that correctly abstracts the boundary
3. Ensuring the protocol lives at the correct layer (L0) without violating layer rules
4. Updating both services and their call sites without breaking behavior
5. Ensuring test coverage remains intact

This demands deep reasoning about architectural boundaries and layer constraints. Opus is the correct choice.

---

## 5. Worktree Isolation

**Yes, worktree isolation is used.**

Complex tasks mandate worktree isolation per the skill definition. The specific actions:

1. Create a worktree with branch `refactor/break-circular-dep-user-auth`
2. Sub-agent operates entirely within the worktree
3. Validation pipeline runs inside the worktree
4. Only after all validations and cross-review pass are changes merged back

This ensures the main branch is never in a broken state during the refactoring. If the refactor goes wrong, the worktree is simply discarded.

---

## 6. Pre-Validation Before Adding Imports

Before creating the new protocol file in `types/` (Layer 0) and before modifying any cross-module imports, the executor runs:

```bash
./scripts/lint-deps
```

This is the pre-validation rule from Step 6: "Before creating files in new locations or adding cross-module imports, run `./scripts/lint-deps` to catch layer violations BEFORE they happen."

Specifically, the pre-validation checks:

1. **Before creating `types/AuthProviding.swift`:** Confirm that `types/` is Layer 0 and that the new protocol does not need to import anything from Layer 3. Layer 0 allows no internal imports. The protocol must be self-contained or import only other Layer 0 types.

2. **Before modifying imports in `services/UserService.swift`:** Confirm that importing from `types/` (Layer 0) into `services/` (Layer 3) is legal. Per layer rules, Layer 3 can import L0, L1, L2 — so importing from types/ to services/ is valid.

3. **Before modifying imports in `services/AuthService.swift`:** Confirm that removing the UserService import does not break any downstream dependency.

If `lint-deps` reports any violation at this stage, the executor stops and adjusts the plan before making any changes.

---

## 7. Validation Pipeline Steps

Since this is a structural/architectural change, the full 5-step validation pipeline runs:

```bash
# Step 1: BUILD
swift build
# Verifies all Swift code compiles after the refactor

# Step 2: LINT ARCHITECTURE
./scripts/lint-deps
# Verifies layer dependencies are correct — critical for this task
# since we are restructuring the dependency graph

# Step 3: LINT QUALITY
./scripts/lint-quality
# Verifies code quality: file length, naming, no hardcoded values

# Step 4: TEST
swift test
# Runs all unit and integration tests — ensures behavior is preserved

# Step 5: VERIFY (E2E)
python3 scripts/verify/run.py
# Runs end-to-end functional verification
```

All 5 steps run because the task is a structural/architectural change, which maps to "Full pipeline" in the validation reference's impact-to-steps table.

After the sub-agent completes execution, it reports its impact scope:

```json
{
  "files_changed": [
    "types/AuthProviding.swift",
    "services/UserService.swift",
    "services/AuthService.swift"
  ],
  "packages_affected": ["types", "services"],
  "new_imports_added": true,
  "new_files_created": true
}
```

This impact scope confirms the full pipeline is needed (new files created + new imports across packages + structural change).

---

## 8. Cross-Review

**Cross-review applies.** This is a Complex task, and cross-review runs for all medium/complex tasks.

**Review model: sonnet** (different from the coding model, which was opus)

The cross-review delegation would be:

```python
Agent(
    description="Review: break-circular-dep-user-auth",
    model="sonnet",  # Different from coding model (opus)
    prompt="""Review these changes for:
1. Logic correctness and edge cases
   - Does the protocol correctly capture the dependency boundary?
   - Are there any remaining circular references?
   - Are there edge cases where UserService still reaches for AuthService directly?

2. Consistency with architecture in AGENTS.md
   - Is the protocol in the correct layer (L0)?
   - Do all imports respect layer hierarchy?
   - Is dependency injection used consistently?

3. Naming clarity and code readability
   - Is the protocol name descriptive (e.g., AuthProviding)?
   - Are the injected parameters clearly named?

4. Performance implications
   - Does protocol-based dispatch introduce any unacceptable overhead?
   - Are there any unnecessary allocations from the refactoring?

Changes: {diff of all modified files}
Task context: Break circular dependency between UserService and AuthService using protocol-based approach
Project docs: docs/ARCHITECTURE.md

Report: PASS (no issues) or ISSUES (list each with severity: CRITICAL/HIGH/MEDIUM)"""
)
```

**Why sonnet and not haiku:** The review is of an architectural refactoring. While haiku could handle simple reviews, this involves understanding layer constraints, protocol design correctness, and dependency graph analysis. Sonnet provides sufficient reasoning capability for review (without needing opus-level depth since it is reviewing, not designing).

**Review outcome handling:**
- PASS -> Proceed to Step 8 (Complete)
- MEDIUM issues -> Note, proceed to Complete
- HIGH issues -> Fix via sub-agent (opus), re-validate affected pipeline steps
- CRITICAL issues -> Fix via sub-agent (opus), run full validation pipeline

---

## 9. Checkpoints

All five checkpoints are saved for this Complex task:

| Checkpoint | When Saved | Content |
|------------|-----------|---------|
| `phase-1-context-loaded` | After reading AGENTS.md, ARCHITECTURE.md, DEVELOPMENT.md, memory INDEX.md | Task objective, files read, layer map showing services/ at Layer 3 and types/ at Layer 0 |
| `phase-2-plan-approved` | After human reviews and approves the execution plan | Full plan content, human approval confirmation |
| `phase-3-execution-complete` | After sub-agent finishes code changes | List of files changed, diff summary, any issues encountered during execution |
| `phase-4-validated` | After all 5 validation pipeline steps pass | Validation results for each step (build, lint-deps, lint-quality, test, verify) |
| `phase-5-reviewed` | After cross-review completes | Review model's findings, any fixes applied, final review result |

Checkpoint format follows the JSON structure from the checkpoint reference, e.g.:

```json
{
  "task": "break-circular-dep-user-auth",
  "phase": "phase-1-context-loaded",
  "timestamp": "2026-04-19T10:30:00Z",
  "context": {
    "objective": "Break circular dependency between UserService and AuthService using protocol-based approach",
    "files_read": ["AGENTS.md", "docs/ARCHITECTURE.md", "docs/DEVELOPMENT.md", "harness/memory/INDEX.md"],
    "layer_map": {
      "types/": 0,
      "utils/": 1,
      "config/": 2,
      "services/": 3
    }
  },
  "architecture_decisions": [
    "Protocol to be created in types/ (Layer 0) with no Layer 3 imports",
    "UserService receives AuthProviding via dependency injection",
    "AuthService conforms to AuthProviding protocol"
  ]
}
```

All checkpoints are saved to `harness/trace/checkpoints/break-circular-dep-user-auth/`.

---

## 10. Trajectory Compilation

**Trajectory compilation does NOT apply yet for this specific execution.**

Trajectory compilation only triggers when ALL three conditions are met:

1. Procedural memory exists for this task type
2. Success count >= 3
3. Steps are consistent across executions

For this task, assuming it is the first time performing a "break circular dependency" refactor:

- No procedural memory exists yet for `break-circular-dependency` in `harness/memory/procedural/`
- Success count is 0 (this is the first execution)
- Steps are not yet proven consistent

**What happens instead in the COMPLETE step:**

1. A new procedural memory entry is created at `harness/memory/procedural/break-circular-dependency.md` documenting the successful pattern:

   ```markdown
   # Procedure: break-circular-dependency

   ## When to Use
   When two services in the same layer have a circular import dependency.

   ## Steps
   1. Analyze the exact methods/properties creating the cycle
   2. Design a protocol abstraction at Layer 0 (types/)
   3. Make one service conform to the protocol
   4. Replace the other service's concrete dependency with the protocol via DI
   5. Update call sites to inject the concrete implementation
   6. Update tests to use protocol mocks

   ## Success Rate
   1/1 successful executions

   ## Last Validated
   2026-04-19
   ```

2. The memory INDEX.md is updated to include this new procedural entry.

3. An episodic memory may be written if any non-obvious lesson was learned during execution (e.g., "Swift protocols in Layer 0 cannot have associated types that reference Layer 3 types").

4. The INDEX.md will NOT be marked with `READY TO COMPILE` since success count is only 1/3.

**Future trajectory:** If this same pattern is executed successfully two more times (total 3+) with consistent steps, the next execution would flag the entry as `READY TO COMPILE` and prompt the user to compile it into `scripts/break-circular-dependency.sh`.

---

## Summary of the Complete Workflow

```
Step 1: DETECT
  -> Check AGENTS.md exists
  -> If missing, invoke harness-creator, then resume

Step 2: LOAD
  -> Read AGENTS.md, docs/ARCHITECTURE.md, docs/DEVELOPMENT.md
  -> Read harness/memory/INDEX.md for relevant patterns
  -> Read references/layer-rules.md (will be needed for import changes)
  -> Save checkpoint: phase-1-context-loaded

Step 3: PLAN (Complex)
  -> Classify as Complex (architecture change, multi-file, "and" clauses)
  -> Create execution plan at docs/exec-plans/break-circular-dep-user-auth.md
  -> Plan includes: 6 ordered steps, full validation checklist, rollback plan
  -> Save checkpoint: phase-2-plan-approved (after approval)

Step 4: APPROVE
  -> Present plan to human: objective, scope (3+ files across 2 layers), risk (structural refactoring)
  -> Wait for explicit approval
  -> Do not proceed until human confirms

Step 5: EXECUTE (Complex)
  -> Create worktree: branch refactor/break-circular-dep-user-auth
  -> Run pre-validation: ./scripts/lint-deps (check layer rules before changes)
  -> Delegate to sub-agent:
     - Model: opus (deep reasoning, refactoring, architecture)
     - Task: Execute the 6 steps from the plan
     - Read: docs/ARCHITECTURE.md, layer rules
     - Validate after each major step
  -> Save checkpoint: phase-3-execution-complete

Step 6: VALIDATE (Full Pipeline)
  -> swift build (compile check)
  -> ./scripts/lint-deps (layer dependency check)
  -> ./scripts/lint-quality (code quality check)
  -> swift test (all tests)
  -> python3 scripts/verify/run.py (E2E verification)
  -> If any step fails: self-repair loop (max 3 attempts, context budget 40 tool calls)
  -> Save checkpoint: phase-4-validated

Step 7: CROSS-REVIEW (Complex)
  -> Delegate review to sonnet (different from opus coding model)
  -> Review focus: protocol correctness, layer compliance, no remaining cycles, edge cases
  -> If CRITICAL/HIGH: fix via sub-agent, re-validate
  -> Max 2 review-fix rounds before escalating to human
  -> Save checkpoint: phase-5-reviewed

Step 8: COMPLETE
  -> Git: commit on worktree branch, push, optionally create PR
  -> Memory: Write procedural memory for break-circular-dependency pattern (1/1 success)
  -> Memory: Write episodic memory if non-obvious lessons learned
  -> Trace: Write success record to harness/trace/
  -> Trajectory: Check compilation trigger -> NOT MET (success count 1/3, need 3+)
  -> Summarize: "Completed break-circular-dep-user-auth. Validated: build PASS, lint PASS, test PASS, verify PASS, review PASS"
```
