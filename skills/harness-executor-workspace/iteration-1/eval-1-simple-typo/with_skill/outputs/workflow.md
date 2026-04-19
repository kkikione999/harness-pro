# Workflow Description: Fix Typo in docs/ARCHITECTURE.md

## Task

Fix the typo in `docs/ARCHITECTURE.md` where `' Layer 3'` should be `'Layer 3'` (extra space before "Layer 3" on line 15). Just fix the typo, nothing else.

---

## Step 1: DETECT — Check AGENTS.md Exists

Check whether `AGENTS.md` exists at the project root.

- **Action**: Run `test -f AGENTS.md`.
- **Outcome**: If present, proceed. If missing, invoke `harness-creator` to bootstrap, then resume.
- **In this case**: Proceed (assumed present for a Harness-managed project).

## Step 2: LOAD — Read Context Files

Read the project context files to understand the codebase structure:

1. `AGENTS.md` — Entry point, layer rules, build commands
2. `docs/ARCHITECTURE.md` — The file containing the typo; read to understand its structure and confirm the error location
3. `docs/DEVELOPMENT.md` — Build commands, common tasks

Also check `harness/memory/INDEX.md` for relevant past patterns.

For this task, the key file is `docs/ARCHITECTURE.md` itself. Read it to locate line 15 and confirm the extra space before "Layer 3".

## Step 3: PLAN — Analyze Complexity

### Complexity Classification: SIMPLE

Apply the complexity decision tree from the skill:

```
Can you describe the task in one sentence without "and"?
"Fix a single extra-space typo on line 15 of docs/ARCHITECTURE.md."
→ YES → Simple: execute directly
```

The task matches the **Simple** row in the complexity table:

| Complexity | Criteria | Action |
|------------|----------|--------|
| **Simple** | Single file, typo fix, one-liner | Execute directly |

**Rationale**:
- Single file affected (`docs/ARCHITECTURE.md`)
- Single character change (remove one leading space)
- No logic change, no cross-module impact
- No architectural decision needed

**Dynamic escalation check**: No escalation signals apply:
- Does not touch >3 files
- No cross-module imports
- Does not require >2 files to change
- No architectural decision needed

### Execution Plan

No formal execution plan file (`docs/exec-plans/{task-name}.md`) is created. Step 4 (Plan & Approve) only applies to medium/complex tasks.

## Step 4: APPROVE — Skip

**Skipped.** The skill specifies: "For medium/complex tasks, create an execution plan... Wait for human approval before proceeding to Step 5."

This is a Simple task. No execution plan is written, and no human approval gate is needed.

## Step 5: EXECUTE — Direct Execution

**Mode**: Direct execution (not delegated to a sub-agent).

The skill states: "Simple Tasks — Use direct execution (this is the ONLY case where coordinator writes code)."

**Specific actions**:

1. Read `docs/ARCHITECTURE.md`, specifically around line 15, to confirm the typo.
2. Edit line 15: change `' Layer 3'` to `'Layer 3'` (remove the leading space).
3. Confirm the change is exactly one character removed from one line.

**No sub-agent delegation.** The coordinator handles this directly because it is a Simple task (typo fix, single file, one-liner).

**Model selection**: N/A — no delegation occurs.

## Step 6: VALIDATE — Run Pipeline (Reduced)

Consult the validation reference for which pipeline steps apply based on impact scope:

| Scenario | Steps to Run |
|----------|-------------|
| Simple file edit | build → test |

The impact scope assessment:

```json
{
  "files_changed": ["docs/ARCHITECTURE.md"],
  "packages_affected": [],
  "new_imports_added": false,
  "new_files_created": false
}
```

This is a **documentation-only change** (a `.md` file). The validation steps that are meaningful:

1. **build**: Likely not applicable — `docs/ARCHITECTURE.md` is a Markdown file, not source code. Running `swift build`, `go build`, or `npm build` would not be affected by a documentation typo. However, per the skill's pipeline, we run build first. It should pass trivially since no source code changed.
2. **lint-deps**: Skipped — no cross-module imports involved.
3. **lint-quality**: Skipped — no source code quality concerns for a whitespace fix in a `.md` file.
4. **test**: Skipped — no test would be affected by a documentation typo fix.
5. **verify (E2E)**: Skipped — no functional behavior changed.

**Pragmatic validation**: For a single-character whitespace fix in a Markdown documentation file, the practical validation is:
- Confirm the file still exists and is well-formed.
- Confirm the typo is fixed (visually verify line 15 now reads `Layer 3` without the leading space).
- Optionally run `git diff` to confirm the diff is exactly what was intended (one line changed, one space removed).

**If validation scripts are run mechanically**: `build` and `test` steps pass trivially since no source code is affected. The remaining lint and verify steps are skipped per the incremental validation rules.

## Step 7: CROSS-REVIEW — Skip

**Skipped.** The cross-review reference explicitly lists when to skip:

> - **Simple tasks** — direct execution, no delegation occurred
> - **Changes < 20 lines** with no logic change (formatting, renames)

Both criteria apply:
- This is a Simple task (direct execution, no delegation).
- The change is 1 line, and it is a formatting fix (whitespace removal), not a logic change.

No cross-review is performed.

## Step 8: COMPLETE — Git Commit and Trace

### Git Operations

Per the completion reference, for Simple tasks:

| Complexity | Branch Strategy |
|-----------|----------------|
| Simple | Direct commit on current branch |

**Specific git actions**:

1. Stage the specific file: `git add docs/ARCHITECTURE.md`
2. Commit with conventional format: `git commit -m "docs: fix extra space typo on line 15 of ARCHITECTURE.md"`
3. No push, no PR — Simple tasks commit directly on the current branch.

### Memory

- **Episodic memory**: Not written for a trivial typo fix (no meaningful lesson).
- **Procedural memory**: Not written (this is a one-off task, not a repeatable pattern).
- **Failure trace**: Not written (task succeeded).

### Trajectory Compilation Check

Skipped. Trajectory compilation requires success count >= 3 with consistent steps. A one-off typo fix does not qualify.

### Summary

"Completed typo fix in docs/ARCHITECTURE.md (removed extra leading space on line 15). Validated: build (pass), no source code impact. Simple task — direct execution, no delegation, no cross-review."

---

## Summary Table

| Step | Action | Details |
|------|--------|---------|
| 1. DETECT | Execute | Check AGENTS.md exists |
| 2. LOAD | Execute | Read AGENTS.md, docs/ARCHITECTURE.md, docs/DEVELOPMENT.md, check harness/memory/INDEX.md |
| 3. PLAN | Execute | Classify as **Simple** (single file, typo, one-liner). No formal execution plan. |
| 4. APPROVE | **Skip** | Only for medium/complex tasks |
| 5. EXECUTE | Execute directly | Coordinator makes the edit directly. No sub-agent delegation. |
| 6. VALIDATE | Execute (reduced) | Build + test pass trivially (docs-only change). Lint-deps, lint-quality, verify skipped per incremental validation rules. Practical check: `git diff` confirms intended change. |
| 7. CROSS-REVIEW | **Skip** | Simple task, change < 20 lines, formatting-only |
| 8. COMPLETE | Execute | `git add docs/ARCHITECTURE.md` then `git commit -m "docs: fix extra space typo on line 15 of ARCHITECTURE.md"`. No memory write, no trajectory compilation. |
