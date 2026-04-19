# Workflow Description: harness-executor for "Fix integration test that passes locally but fails on CI"

This document describes exactly what the harness-executor skill's 8-step workflow would do for the given task, with full detail on all memory operations.

---

## Step 1: Detect Environment

**Action:** Check whether `AGENTS.md` exists in the project root.

**Outcome:** AGENTS.md exists (per scenario: "The project has AGENTS.md and full Harness infrastructure"). Harness detected, proceeding with normal workflow.

---

## Step 2: Load Context

**Action:** Read the following files to understand the project.

**Files to read (in order):**
1. `AGENTS.md` -- Entry point, layer rules, build commands
2. `docs/ARCHITECTURE.md` -- Layer diagram, package responsibilities
3. `docs/DEVELOPMENT.md` -- Build commands, common tasks
4. `harness/memory/INDEX.md` -- Check for relevant patterns and past lessons

**Memory lookup before planning:**
- Scan `INDEX.md` for procedural memory matching "fix-test" or "fix-integration-test" task types
- Check episodic memory for lessons related to CI failures, path handling, or cross-platform issues
- Check recent failures for pitfalls related to test infrastructure

**Checkpoint:** Save `phase-1-context-loaded` checkpoint.

---

## Step 3: Analyze Task Complexity

**Task description:** "Fix the integration test that passes locally but fails on CI"

**Applying the Complexity Decision Tree:**

```
Can you describe the task in one sentence without "and"?
"Fix a test that compares file paths using exact string match, which breaks on CI because macOS resolves /var as a symlink to /private/var but Linux does not."
```

The task requires identifying the root cause across a local-vs-CI discrepancy, then applying a targeted fix. It involves:
- Diagnosing an environment-specific failure (local vs CI)
- Fixing path comparison logic in a test file
- The fix itself is single-file, but the diagnosis is non-trivial

```
Does it affect multiple files consistently?
    Potentially -- if the same pattern exists in other tests, but the primary fix is single-file.
```

**Complexity Classification: MEDIUM**

Rationale:
- The diagnosis phase involves understanding cross-platform behavior (non-obvious constraint)
- The sub-agent must investigate and discover the symlink issue
- Multi-file changes are possible if the same pattern exists elsewhere
- The fix is consistent (replace string comparison with Path.resolve()) but the investigation requires judgment

**Dynamic Escalation Watch:** If the sub-agent discovers the pattern is widespread (touching >3 test files), escalate from Medium to Complex (sub-agent + worktree isolation). For this scenario, escalation does NOT occur -- the fix is confined to one test file.

---

## Step 4: Plan and Approve

**Action:** Create an execution plan at `docs/exec-plans/fix-integration-test-ci.md`.

**Full Execution Plan Content:**

```markdown
# Execution Plan: fix-integration-test-ci

## Objective
Fix the integration test that passes locally (macOS) but fails on CI (Linux) by replacing exact string path comparison with resolved path comparison.

## Impact Scope
- `tests/integration/` (test layer) -- Test file(s) with path comparison logic
- No production code changes expected

## Steps
1. Run the failing test locally to confirm it passes on macOS
2. Examine the test code to identify where file paths are compared using exact string match
3. Identify the root cause: macOS /var is symlink to /private/var, CI Linux /var is real directory
4. Replace exact string comparison with Path.resolve() (or equivalent) to normalize symlinks
5. Verify fix by simulating the Linux path resolution behavior locally
6. Check if the same pattern exists in other test files

## Validation
- [ ] Build passes
- [ ] Tests pass (including the previously failing integration test)
- [ ] lint-quality passes
- [ ] verify passes (if applicable)

## Rollback Plan
Single file change. Branch: `fix/integration-test-ci-path`. Revert via `git revert`.

## Checkpoint After
- phase-2: After plan is approved
- phase-3: After execution is complete
- phase-4: After validation passes
```

**Approval Process:**
1. Present summary to human: "Objective: Fix CI-only integration test failure. Scope: 1-2 test files. Risk: Low (test-only change, no production code)."
2. Wait for explicit human approval.
3. Proceed after approval.

---

## Step 5: Execute

**Action:** Delegate to a sub-agent. The coordinator does NOT write code directly for Medium tasks.

**Model Selection: `sonnet`**

Rationale:
- `haiku` is for simple changes. This requires investigative debugging (understanding symlink behavior, path resolution across platforms).
- `sonnet` is for medium complexity, code generation with judgment. This task requires both diagnosis and a targeted fix.
- `opus` is for deep reasoning and architecture. No architectural decision is needed here.

**Sub-agent invocation:**

```python
Agent(
    description="Execute: fix-integration-test-ci",
    model="sonnet",
    prompt="""Fix the integration test that passes locally on macOS but fails on CI (Linux).

Read: docs/ARCHITECTURE.md
Read: docs/DEVELOPMENT.md

The test compares file paths using exact string match. On macOS, /var is a symlink
to /private/var, so resolved paths differ from literal paths. On CI (Linux), /var is
a real directory, so the comparison fails.

Steps:
1. Find the integration test file with the path comparison
2. Identify all locations where paths are compared using exact string match
3. Replace string comparison with Path.resolve() to normalize symlinks
4. Verify the fix does not break any other tests

Constraints:
- Only modify test files
- Use Path.resolve() (or project's equivalent) for path comparison
- Do not change production code
- Validate after each major step
- Report back with diff + validation results"""
)
```

**Sub-agent discovers and reports:**
1. The test compares file paths using exact string match (e.g., `assert path == expected_path`)
2. On macOS, `/var` is a symlink to `/private/var`, so `Path("/var/tmp")` resolves to `/private/var/tmp` -- but since the test uses string comparison, it works locally because both sides go through the same resolution
3. On CI (Linux), `/var` is a real directory, so the resolved path differs from what was stored/expected
4. Fix: Replace `assert path == expected_path` with `assert Path(path).resolve() == Path(expected_path).resolve()`
5. The pattern exists in only one test file; no other files are affected

**Checkpoint:** Save `phase-3-execution-complete` after sub-agent reports back with the fix.

---

## Step 6: Validate (The Pipeline)

**Action:** Run the validation pipeline in order, stopping on first failure.

**Impact scope assessment from sub-agent:**

```json
{
  "files_changed": ["tests/integration/path_comparison_test.py"],
  "packages_affected": ["tests"],
  "new_imports_added": false,
  "new_files_created": false
}
```

**Validation steps (per incremental validation rules):**

Single file, no new imports: build -> test (affected package only)

| Step | Command | Result |
|------|---------|--------|
| 1. Build | `make build` | PASS -- no source code changed |
| 2. Test | `make test` (or targeted test run) | PASS -- previously failing integration test now passes; no regressions |

Lint-deps and lint-quality are skipped because:
- No cross-module imports were added
- No new files were created
- The change is test-only

**Self-Repair Loop:** Not needed -- all validations pass on first attempt.

**Checkpoint:** Save `phase-4-validated`.

---

## Step 7: Cross-Review

**Action:** Delegate review to a different model.

**Skip?** The cross-review reference says to skip for "test-only changes." However, this is a MEDIUM task, and the change involves a logic correction (path resolution), not just formatting. The skill says cross-review applies to "Medium/Complex Tasks Only." Let's evaluate the skip criteria:

- **Simple tasks** -- No, this is Medium
- **Changes < 20 lines with no logic change** -- The change is likely < 20 lines, but it IS a logic change (string comparison to path resolution)
- **Auto-generated or boilerplate code** -- No
- **Test-only changes** -- Yes, this is test-only

**Decision:** Per the cross-review reference: "Skip for: ... Test-only changes -- new tests, test fixes." This is a test fix. **Cross-review is skipped.**

---

## Step 8: Complete

### Git Operations

Branch strategy for Medium: Feature branch, commit, optionally PR.

```bash
# 1. Feature branch
git checkout -b fix/integration-test-ci-path

# 2. Stage specific files
git add tests/integration/path_comparison_test.py

# 3. Commit
git commit -m "fix: use Path.resolve() for cross-platform path comparison in integration test

The test compared file paths using exact string match, which passed on macOS
(where /var symlinks to /private/var) but failed on CI Linux (where /var is a
real directory). Using Path.resolve() normalizes symlinks before comparison."

# 4. Push
git push -u origin fix/integration-test-ci-path
```

### Memory Write

This is the core of the scenario. The discovery that `/var` on macOS is a symlink to `/private/var` -- and that this causes cross-platform test failures -- is a **non-obvious constraint** that should be recorded as **episodic memory**.

---

### Question 1: What EPISODIC memory gets written?

**File:** `harness/memory/episodic/2026-04-19-macos-symlink-path-comparison.md`

**Exact content:**

```markdown
# Episode: 2026-04-19-macos-symlink-path-comparison

## Context
While fixing an integration test that passed locally (macOS) but failed on CI (Linux), the sub-agent discovered that the test compared file paths using exact string match (`assert path == expected_path`). On macOS, `/var` is a symlink to `/private/var`, so `Path("/var/tmp")` resolves to `/private/var/tmp`. On Linux (CI), `/var` is a real directory with no symlink. This meant that the path strings matched locally (both sides went through the same macOS resolution) but diverged on CI where the resolution behavior differed. The affected test was in `tests/integration/path_comparison_test.py`.

## Lesson
macOS has several symlinks that do not exist on Linux: `/var` -> `/private/var`, `/tmp` -> `/private/tmp`, `/etc` -> `/private/etc`. When tests compare file paths, exact string comparison is unreliable across platforms. Always use `Path.resolve()` (or the project's equivalent path normalization) to resolve symlinks before comparing paths. This applies to any code that stores, compares, or asserts on filesystem paths.

## Impact
- When writing or reviewing tests that involve file paths, always use `Path.resolve()` for comparison rather than exact string match.
- When debugging "works on my machine" test failures, check whether the test logic depends on platform-specific filesystem behavior (symlinks, case sensitivity, path separators).
- Consider adding this pattern to lint-quality as a check: flag `assert.*==.*path` or similar string-based path comparisons in test files.
```

### Question 2: Does this also warrant updating any other documentation?

Yes. Two additional updates are warranted:

**a) `docs/DEVELOPMENT.md` -- Add a cross-platform testing note:**

Add a section under the testing guidelines:

```markdown
## Cross-Platform Testing Notes

When writing tests that involve file system paths:
- Always use `Path.resolve()` before comparing paths
- macOS symlinks: `/var` -> `/private/var`, `/tmp` -> `/private/tmp`, `/etc` -> `/private/etc`
- These symlinks do not exist on Linux, causing tests to pass on macOS but fail on CI
- See `harness/memory/episodic/2026-04-19-macos-symlink-path-comparison.md` for the full incident
```

**b) `harness/trace/` -- Write a success trace record:**

Write a success trace to `harness/trace/2026-04-19-fix-integration-test-ci.json`:

```json
{
  "timestamp": "2026-04-19T14:30:00Z",
  "task": "fix-integration-test-ci",
  "complexity": "medium",
  "model": "sonnet",
  "files_changed": ["tests/integration/path_comparison_test.py"],
  "validation": {
    "build": "pass",
    "test": "pass",
    "lint_deps": "skipped",
    "lint_quality": "skipped",
    "verify": "skipped"
  },
  "cross_review": "skipped (test-only change)",
  "episodic_memory_written": true,
  "procedural_memory_written": false,
  "trajectory_compilation": false
}
```

**c) `scripts/lint-quality` -- Consider adding a rule (future):**

The episodic memory suggests: "Consider adding this pattern to lint-quality as a check: flag string-based path comparisons in test files." This would be a candidate for the Critic -> Refiner loop to eventually harden into a lint rule, but it is NOT done immediately during this task. It is noted in the episodic memory for future action.

### Question 3: Show the updated INDEX.md content after this task.

Assuming INDEX.md previously existed with some entries, here is what it looks like after this task:

```markdown
# Memory Index

## Procedural (Successful Patterns)
- [add-api-endpoint](procedural/add-api-endpoint.md) -- 5-step flow, 7/8 success, last: 2026-04-18
- [add-database-model](procedural/add-database-model.md) -- 4-step flow, 3/3 success, last: 2026-04-15 <-- READY TO COMPILE

## Episodic (Lessons)
- [macos-symlink-path-comparison](episodic/2026-04-19-macos-symlink-path-comparison.md) -- macOS /var symlink causes cross-platform test failures; use Path.resolve() for path comparison
- [test-isolation](episodic/test-isolation.md) -- Shared state causes flaky tests in services/

## Recent Failures (Last 7 days)
- [cache-layer-violation](../trace/failures/2026-04-17-cache-import.json) -- 3 occurrences, root cause: missing lint mapping
```

The key addition is the new episodic entry `[macos-symlink-path-comparison]` which is added to the Episodic section. The entry includes:
- A descriptive slug: `macos-symlink-path-comparison`
- The filename: `episodic/2026-04-19-macos-symlink-path-comparison.md`
- A one-line summary for quick scanning: "macOS /var symlink causes cross-platform test failures; use Path.resolve() for path comparison"

### Question 4: What procedural memory (if any) is written?

**No procedural memory is written for this task.**

Rationale from the memory reference:

Procedural memory should be written when:
- Same task executed successfully 3+ times
- Steps are consistent enough to be scripted
- Can be compiled into deterministic script

This is a one-off bug fix specific to a particular test file. The steps are not repeatable in a generic sense -- "fix integration test that passes locally but fails on CI" could have a thousand different root causes. The lesson (use Path.resolve()) is captured in episodic memory, which is the correct memory type for this discovery.

If, in the future, the same pattern of "fix CI-only test failure" is executed successfully 3+ times with consistent diagnostic steps (run test locally -> check CI logs -> identify platform-specific behavior -> apply platform-aware fix), then a procedural memory entry like `fix-ci-only-test-failure` could be created. But that threshold has not been reached with a single execution.

### Question 5: Why is this episodic memory valuable for future executions?

This episodic memory is valuable for five specific reasons:

**1. Faster diagnosis of similar failures.** The next time a sub-agent encounters a "passes locally but fails on CI" test failure, the executor reads INDEX.md during Step 2 (Load Context), sees the `macos-symlink-path-comparison` entry, and can immediately check whether path comparison is the issue. This reduces diagnosis time from "investigate from scratch" to "check known pattern first."

**2. Prevention before occurrence.** When a sub-agent is about to write code that compares file paths, the executor can proactively check episodic memory and instruct the sub-agent to use `Path.resolve()` from the start, preventing the bug entirely.

**3. Feeds the Critic -> Refiner loop.** The episodic memory notes: "Consider adding this pattern to lint-quality." This is a signal for the Critic (which periodically analyzes memory patterns). If the same category of issue appears multiple times in episodic memory, the Critic can trigger the Refiner to add a lint-quality rule that flags string-based path comparisons -- converting soft knowledge (episodic memory) into a hard rule (lint script).

**4. Documentation of non-obvious platform behavior.** The macOS symlink behavior (`/var` -> `/private/var`) is exactly the kind of environmental quirk that is not documented in any project's architecture docs, but causes real failures. Without episodic memory, this knowledge lives only in the developer's head (or is lost entirely). With episodic memory, it becomes part of the project's institutional knowledge.

**5. Improves planning accuracy.** During Step 3 (Plan), the executor can reference this memory when assessing task complexity. A task that involves "file path handling in tests" would be classified more accurately because the executor knows about the cross-platform pitfall, potentially leading to a more thorough execution plan or earlier delegation to a sub-agent with specific platform-awareness instructions.

---

## Summary Table

| Step | Action | Details |
|------|--------|---------|
| 1. DETECT | Execute | AGENTS.md exists, proceed |
| 2. LOAD | Execute | Read AGENTS.md, docs/, harness/memory/INDEX.md |
| 3. PLAN | Execute | Classified as **MEDIUM** (diagnosis + single-file fix, non-obvious root cause) |
| 4. APPROVE | Execute | Create execution plan, wait for human approval |
| 5. EXECUTE | Delegate to sub-agent | Model: sonnet (medium complexity, diagnosis + fix). Sub-agent discovers macOS symlink issue. |
| 6. VALIDATE | Execute (reduced) | build -> test. Both pass. No lint needed (test-only, no new imports/files). |
| 7. CROSS-REVIEW | **Skip** | Test-only change per skip criteria |
| 8. COMPLETE | Execute | Git commit on feature branch. **Episodic memory written** (macOS symlink lesson). Procedural memory: NO. Trajectory compilation: NO. |

## Memory Artifacts Summary

| Artifact | Written? | Path |
|----------|----------|------|
| Episodic memory | **YES** | `harness/memory/episodic/2026-04-19-macos-symlink-path-comparison.md` |
| INDEX.md update | **YES** | `harness/memory/INDEX.md` (new episodic entry added) |
| Procedural memory | NO | N/A -- first execution, not a repeatable pattern |
| Failure trace | NO | N/A -- task succeeded |
| Success trace | **YES** | `harness/trace/2026-04-19-fix-integration-test-ci.json` |
| DEVELOPMENT.md update | **YES** | `docs/DEVELOPMENT.md` (cross-platform testing note added) |
| Trajectory compilation | NO | N/A -- success count < 3, not a repeatable pattern |

## Exit Code: 0

Task completed, all validations passed, episodic memory written for future benefit.
