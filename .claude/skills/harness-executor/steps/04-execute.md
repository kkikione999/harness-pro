# Step 4: Execute & Review

## Simple Tasks

Edit directly. This is the only case where you write code yourself.

## Medium/Complex Tasks

### 1. Spawn worker sub-agent

Spawn a **worker sub-agent** (loading `harness-worker` skill). Pass in the spawn prompt:
- Plan file path
- Phase(s) to execute
- Forbidden list and post conditions from the plan
- Files to read (AGENTS.md, ARCHITECTURE.md, DEVELOPMENT.md)

The worker implements the phase(s) and returns results.

### 2. Verify boundaries

After worker returns, check:
```bash
git diff --name-only
```
Verify no files outside the plan's scope were modified.

### 3. Spawn reviewer sub-agent

Spawn a **reviewer sub-agent** (loading `harness-reviewer` skill). Pass in the spawn prompt:
- Task description
- Plan file path
- Changed files list
- Diff of changes
- Project docs locations

The reviewer returns a graded report (PASS / MEDIUM / HIGH / CRITICAL).

If grade is HIGH or CRITICAL, spawn worker sub-agent again to fix issues, then re-run reviewer. Max 2 review-fix rounds before escalating to human.
