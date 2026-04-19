# Workflow Description: harness-executor for "Add harness validate CLI Command"

This document describes exactly what the harness-executor skill's 8-step workflow would do for the given task.

---

## Step 1: Detect Environment

**Action:** Check whether `AGENTS.md` exists in the project root.

**Specifics:**
```
if [ -f "AGENTS.md" ]; then
    echo "Harness detected, proceeding..."
else
    echo "AGENTS.md not found. Invoking harness-creator..."
fi
```

Looking at the current project structure, there is **no `AGENTS.md`** at the project root. The skill dictates that if `AGENTS.md` is missing, I must invoke `harness-creator` to bootstrap the harness infrastructure (AGENTS.md, docs/, scripts/, harness/ directories, layer rules), then resume the executor workflow.

**Outcome:** Invoke harness-creator first, wait for it to complete, then continue with Step 2. If harness-creator is unavailable, exit with code 127.

---

## Step 2: Load Context

**Action:** Read the following files to understand the project.

**Files to read (in order):**
1. `AGENTS.md` -- Entry point, layer rules, build commands
2. `docs/ARCHITECTURE.md` -- Layer diagram, package responsibilities
3. `docs/DEVELOPMENT.md` -- Build commands, common tasks
4. `harness/memory/INDEX.md` -- Check for relevant patterns and past lessons

**Memory lookup before planning:**
- Scan `INDEX.md` for procedural memory matching "add-cli-command" or similar task types
- Check episodic memory for lessons related to CLI or command registration
- Check recent failures for pitfalls related to the affected modules

**Checkpoint:** Save `phase-1-context-loaded` checkpoint to `harness/trace/checkpoints/add-harness-validate-cli/phase-1-context-loaded.json` with the task objective, files read, and layer map.

---

## Step 3: Analyze Task Complexity

**Task description:** "Add a new CLI command 'harness validate' to the project. This command should call scripts/validate.py and return its exit code. The command should be registered in the main CLI entry point. This affects multiple files (new command file + CLI registration + potential config changes)."

**Applying the Complexity Decision Tree:**

```
Can you describe the task in one sentence without "and"?
```

The task description itself says "This affects multiple files (new command file + CLI registration + potential config changes)." This cannot be described in a single sentence without "and" because it involves:
- Creating a new command file
- Registering the command in the CLI entry point
- Potentially modifying config

```
Does it affect multiple files consistently?
    YES --> Medium: plan + delegate
```

**Complexity Classification: MEDIUM**

Rationale:
- Multi-file changes (new command file, CLI registration, possibly config)
- The changes follow a consistent, repeatable pattern (adding a CLI command is a standard operation)
- No architectural decision needed -- we are following an established pattern
- No refactoring or new module creation required
- Estimated 2-3 files affected

This is squarely in the **Medium** tier: "Multi-file changes, consistent pattern -- Plan, then delegate to sub-agent."

**Dynamic Escalation Watch:** During execution, if the task unexpectedly touches >3 files or requires cross-module imports that were not planned, escalate from Medium to Complex (sub-agent + worktree isolation). For this task, escalation is unlikely unless the CLI entry point requires structural changes.

---

## Step 4: Plan and Approve

**Action:** Create an execution plan at `docs/exec-plans/add-harness-validate-cli.md` using the template from `references/execution-plan.md`. Then wait for human approval.

**Steps executed:** Yes -- this is a non-trivial (Medium) task, so planning is required.

**Full Execution Plan Content:**

```markdown
# Execution Plan: add-harness-validate-cli

## Objective
Add a new CLI command `harness validate` that invokes `scripts/validate.py` and returns its exit code, registered in the main CLI entry point.

## Impact Scope
- `cli/` (Layer 4 -- Interface layer) -- New command file for `validate` subcommand
- `cli/main.py` or equivalent CLI entry point (Layer 4) -- Registration of new command
- `config/` (Layer 2) -- Potential config changes if CLI command behavior needs configuration
- `scripts/validate.py` (Infrastructure, not layered) -- Read-only reference, no changes expected

## Steps
1. Read the existing CLI entry point to understand command registration pattern (identify the registration mechanism: argparse subparsers, click group, or similar)
2. Create new command file at `cli/commands/validate.py` (or following the project's convention for command files) implementing the `validate` subcommand that:
   - Calls `scripts/validate.py` via `subprocess.run`
   - Captures the exit code from the subprocess
   - Returns/sys.exits with that exit code
   - Provides user-friendly output (stdout from validate.py passed through, clear error on failure)
3. Register the `validate` command in the main CLI entry point (add import, add subparser/click command registration)
4. Add a basic test for the new command in the test suite
5. Verify `scripts/validate.py` exists and is executable

## Validation
- [ ] Build passes (`make build` or equivalent)
- [ ] lint-deps passes (new file in cli/ layer -- must verify no layer violations)
- [ ] lint-quality passes (file length, naming conventions)
- [ ] Tests pass (including new test for the command)
- [ ] verify passes (if applicable -- run `python3 scripts/verify/run.py`)

## Rollback Plan
Delete the new command file, remove the registration from CLI entry point. Branch: `feature/add-harness-validate-cli`. Revert via `git revert` on the single commit.

## Checkpoint After
- phase-2: After plan is approved by human
- phase-3: After execution is complete (all files written)
- phase-4: After validation pipeline passes
- phase-5: After cross-review passes
```

**Approval Process:**
1. Write the plan file to `docs/exec-plans/add-harness-validate-cli.md`
2. Present summary to human: "Objective: Add `harness validate` CLI command. Scope: 2-3 files in Layer 4 (CLI). Risk: Low (follows existing pattern)."
3. **Wait for explicit human approval** -- do not proceed until confirmed
4. If human requests changes, update plan and re-present
5. If human rejects, exit with code 3

---

## Step 5: Execute

**Action:** Delegate to a sub-agent. The coordinator does NOT write code directly for Medium tasks.

**Steps executed:** Yes -- delegate to sub-agent.

**Model Selection: `sonnet`**

Rationale for model choice:
- `haiku` is for fast execution, simple changes (single-file, one-liners). This task touches 2-3 files -- too much for haiku.
- `sonnet` is for "Medium complexity, code generation." This task requires generating a new command file with subprocess logic and registering it correctly in the CLI entry point. It involves reading existing patterns and reproducing them. This is exactly the sonnet use case.
- `opus` is for "Deep reasoning, refactoring, architecture." No architectural decisions are needed here. The pattern is established; we just need to follow it.

**Sub-agent invocation:**

```python
Agent(
    description="Execute: add-harness-validate-cli",
    model="sonnet",
    prompt="""Create a new CLI command 'harness validate' that calls scripts/validate.py and returns its exit code.

Read: docs/ARCHITECTURE.md
Read: docs/DEVELOPMENT.md
Read: The existing CLI entry point file to understand the command registration pattern

Steps:
1. Create the validate command file following the project's command file convention
2. The command must:
   - Call scripts/validate.py via subprocess.run
   - Pass through stdout/stderr from validate.py
   - Return the same exit code as validate.py
   - Handle the case where validate.py does not exist (clear error message)
3. Register the command in the main CLI entry point
4. Add a basic test for the new command

Constraints:
- Follow the existing command file pattern exactly
- Keep the command file under 100 lines
- No hardcoded paths -- use the project's path resolution mechanism
- Validate after each major step
- Report back with diff + validation results"""
)
```

**Pre-validation rule:** Before creating the new command file in `cli/` (a new location for this task), run `./scripts/lint-deps` to catch any potential layer violations before they happen. Since the command file will be in Layer 4 (Interface), it can import any lower layer, so violations are unlikely, but the pre-check is mandatory per the skill.

**Checkpoint:** Save `phase-3-execution-complete` after sub-agent reports back with changes.

---

## Step 6: Validate (The Pipeline)

**Action:** Run the validation pipeline in order, stopping on first failure.

**Steps executed:** Yes -- full pipeline for structural changes (new file created).

**Validation Pipeline (run in order):**

Based on the impact scope analysis from `references/validation.md`:
- New files are being created --> Full pipeline minus verify (unless structural)

| Step | Command | Rationale |
|------|---------|-----------|
| 1. Build | `make build` (or equivalent from AGENTS.md) | New file must compile; imports must resolve |
| 2. Lint Architecture | `./scripts/lint-deps` | New file in `cli/` must not violate layer rules; must verify that `cli/` can import from `scripts/` or subprocess infrastructure |
| 3. Lint Quality | `./scripts/lint-quality` | Check file length, naming conventions, no hardcoded strings |
| 4. Test | `make test` or `npm test` (or equivalent) | New test for the command must pass; existing tests must not regress |
| 5. Verify (E2E) | `python3 scripts/verify/run.py` | Only if applicable based on project structure |

**Incremental Validation Strategy:**
Since new files are being created and new imports may be added, the applicable scenario from the validation reference is "New files created: lint-deps -> lint-quality -> build -> test". If the new file does not add cross-module imports, we could use "Single file, no new imports: build -> test" per file, but since we have new files + registration changes, the safer full pipeline is warranted.

**Self-Repair Loop:**
If any step fails:
1. Analyze the error type (build error, layer violation, quality issue, test failure)
2. Delegate fix back to the sub-agent with the specific error
3. Re-run only the failed step and downstream steps (per the incremental repair table from `references/completion.md`)
4. Maximum 3 attempts, context budget of ~40 tool calls
5. On exhaustion: save failure to `harness/trace/failures/` and escalate to human

**Checkpoint:** Save `phase-4-validated` after all validation passes.

---

## Step 7: Cross-Review

**Action:** Delegate review to a different model than the one that wrote the code.

**Steps executed:** Yes -- this is a Medium task.

**Applicability:** Cross-review applies because:
- This is a Medium complexity task (not Simple)
- The changes are > 20 lines (new command file + registration)
- The code involves logic (subprocess handling, exit code propagation, error handling)
- It is NOT auto-generated/boilerplate, NOT test-only, and NOT < 20 lines

**Review Model: `opus`**

Rationale: The code was written by `sonnet`. Per the skill, the reviewer must be a **different model** to avoid blind spot overlap. `opus` is chosen because:
- It provides deeper reasoning for catching logic errors (e.g., edge cases in subprocess exit code handling, signal handling when validate.py is killed, PATH resolution issues)
- It is better at spotting consistency issues with the existing codebase architecture
- `haiku` would be too lightweight for meaningful code review

**Review Delegation:**

```python
Agent(
    description="Review: add-harness-validate-cli",
    model="opus",
    prompt="""Review these changes for:
1. Logic correctness and edge cases
   - Does subprocess.run handle all exit codes correctly?
   - What happens if validate.py hangs or is killed by signal?
   - Is PATH resolution correct across platforms?
   - Are there edge cases where the exit code could be lost?
2. Consistency with architecture in AGENTS.md
   - Does the command file follow the project's established pattern?
   - Is it in the correct layer (Layer 4 / Interface)?
3. Naming clarity and code readability
   - Are function and variable names clear?
   - Is error messaging user-friendly?
4. Performance implications
   - Any unnecessary overhead in the subprocess invocation?

Changes: {diff from git}
Task context: Adding 'harness validate' CLI command that calls scripts/validate.py
Project docs: docs/ARCHITECTURE.md

Report: PASS (no issues) or ISSUES (list each with severity: CRITICAL/HIGH/MEDIUM)"""
)
```

**Review Outcome Handling:**

| Result | Action |
|--------|--------|
| PASS | Proceed to Step 8 (Complete) |
| MEDIUM issues | Note in `harness/trace/`, proceed to Step 8 |
| HIGH issues | Fix via sub-agent, re-validate affected pipeline steps |
| CRITICAL issues | Fix via sub-agent, run full validation pipeline |

If fixes are needed, max 2 rounds of review-fix-revalidate before escalating to human.

**Checkpoint:** Save `phase-5-reviewed` after cross-review passes.

---

## Step 8: Complete

### On Success

**Git Operations:**

Branch strategy for Medium: Feature branch, commit, optionally PR.

```bash
# 1. Create feature branch (if not already on one)
git checkout -b feature/add-harness-validate-cli

# 2. Stage specific files (not git add -A)
git add cli/commands/validate.py
git add cli/main.py  # or whatever the CLI entry point is
git add tests/test_validate_command.py
# (any other specific files that were modified)

# 3. Commit with conventional format
git commit -m "feat: add 'harness validate' CLI command

Adds a new CLI subcommand 'validate' that invokes scripts/validate.py
and returns its exit code. Registers the command in the main CLI entry point."

# 4. Optionally push and create PR
git push -u origin feature/add-harness-validate-cli
# Optionally: gh pr create --title "feat: add harness validate CLI command" --body "..."
```

**Memory Write:**

1. **Procedural memory** -- If this is the first time adding a CLI command, create a new procedural memory entry at `harness/memory/procedural/add-cli-command.md` documenting the pattern (since this is likely the first execution, not 3+, so just record it). If a procedural memory already exists for "add-cli-command", increment the success counter.

2. **Episodic memory** -- If any non-obvious lessons were learned during execution (e.g., the CLI entry point uses a specific registration pattern, or subprocess.run needs a particular flag), write to `harness/memory/episodic/`.

3. **Trace** -- Write success record to `harness/trace/` with the execution summary.

4. **Update INDEX.md** -- Add/update the procedural memory entry in `harness/memory/INDEX.md`.

**Trajectory Compilation Check:**

**Does NOT apply** for this execution.

Rationale: Trajectory compilation requires all three trigger conditions:
1. Procedural memory exists for this task type -- Likely NO (this is probably the first "add-cli-command" execution)
2. Success count >= 3 -- NO (first execution)
3. Steps are consistent across executions -- Cannot determine with only 1 execution

Since at least conditions 1 and 2 are not met, trajectory compilation is not triggered. After 3 successful executions of similar "add-cli-command" tasks, the procedural memory entry would be marked `<< READY TO COMPILE` in INDEX.md, and the user would be prompted: "Pattern 'add-cli-command' succeeded 3x. Compile to script?"

If confirmed, a compiled script would be generated at `scripts/add-cli-command.sh` with the deterministic steps.

**Final Summary:**

"Completed add-harness-validate-cli. Validated: build [pass], lint-deps [pass], lint-quality [pass], test [pass], verify [pass], review [pass]"

---

## Summary: Steps Executed vs Skipped

| Step | Action | Executed? | Notes |
|------|--------|-----------|-------|
| 1. Detect | Check AGENTS.md | YES | AGENTS.md missing; invoke harness-creator first |
| 2. Load | Read AGENTS.md + docs + memory | YES | Load full context and check memory INDEX.md |
| 3. Plan | Analyze complexity, create plan | YES | Classified as MEDIUM; full execution plan created |
| 4. Approve | Human reviews plan | YES | Wait for explicit approval; exit code 3 if rejected |
| 5. Execute | Delegate to sub-agent | YES | Model: sonnet (medium complexity, code generation) |
| 6. Validate | Run pipeline | YES | Full pipeline: build -> lint-deps -> lint-quality -> test -> verify |
| 7. Cross-Review | Different model reviews diff | YES | Model: opus (different from sonnet writer; deep reasoning) |
| 8. Complete | Git commit, memory, trajectory check | YES (partial) | Git + memory: YES. Trajectory compilation: NO (first execution, < 3 successes) |

## Complexity Classification: MEDIUM

Final justification: Multi-file changes (new command file + CLI registration + possible config), consistent pattern (adding a CLI command follows a standard recipe), no architectural decisions required.
