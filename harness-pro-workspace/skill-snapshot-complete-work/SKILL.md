---
name: harness-pro-complete-work
description: >
  Verify completion and handle integration. Use this skill whenever: all implementation tasks
  are complete and you need to finalize. Also trigger when the user says "done", "finish up",
  "wrap this up", "merge this", "create a PR", "ship it", or when moving from execution to
  integration. Even if the user doesn't explicitly say they're done — if all tasks in the
  current feature are implemented and tests pass, this skill should kick in. This is the FINAL
  step in the harness engineering workflow. Iron law: NO COMPLETION CLAIMS WITHOUT FRESH
  VERIFICATION EVIDENCE.
---

# Complete Work Skill

You are a completion agent. Your job is to verify that work is truly done, maintain documentation integrity, and handle integration.

## Iron Law

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

If you haven't run the verification command in this message, you cannot claim it passes. "It passed earlier" is not evidence.

## Step 1: Fresh Verification

Run all verification commands NOW (not from cache, not from memory):

| Check | Command | Expected |
|-------|---------|----------|
| Tests | `{test command from CLAUDE.md}` | All pass, 0 failures |
| Lint | `{lint command from CLAUDE.md}` | 0 errors |
| Build | `{build command from CLAUDE.md}` | Exit 0 |

If the project doesn't have one of these commands, skip it. But if it exists, it must pass.

If any check fails: **fix it first, then re-run.** Do not claim completion with failing checks.

## Step 2: Documentation Maintenance Check

**Any change that touches existing features must update their documentation.**

1. Did this work modify any existing feature?
   - Read `features/` to see which features exist
   - Compare changed files against feature `code_scope_hint` entries

2. For each affected feature, check:
   - Does `index.md` still accurately describe the scope? → Update if scope changed
   - Does `plan.md` reflect the current state? → Update if implementation diverged
   - Are `acceptance_criteria` still valid? → Update if new behaviors were added

3. If new files were created that belong to an existing feature:
   - Update `code_scope_hint` if naming patterns expanded

**Principle: features/ is the source of truth. If it rots, the entire system degrades.**

## Step 3: Integration Options

Present the user with integration choices:

1. **Merge locally** — merge branch into current branch, delete feature branch
2. **Push PR** — push to remote, create pull request
3. **Keep branch** — keep work on current branch, don't merge yet
4. **Discard** — discard all changes (confirm with user first)

Wait for user's choice, then execute.

## Step 4: Cleanup

After integration:

- Clean up `.harness/file-stack/` — archive or remove execution-time documents
- Remove any temporary branches or worktrees
- Ensure working directory is clean

## What NOT to Do

- Do NOT claim "done" without running fresh verification
- Do NOT skip documentation maintenance check
- Do NOT merge without user's explicit choice
- Do NOT use words like "should", "probably", "seems to" — only state verified facts

## Workflow Summary

```
All implementation tasks complete, tests passing
        ↓
Step 1: Fresh Verification
  Run tests → lint → build (all fresh, all pass)
  If any fail → fix → re-run
        ↓
Step 2: Documentation Maintenance
  Check features/ against actual changes
  Update index.md / plan.md if needed
        ↓
Step 3: Integration
  Present options to user
  Execute chosen option
        ↓
Step 4: Cleanup
  Archive .harness/file-stack/
  Clean branches/worktrees
  Verify clean working directory
        ↓
Done
```
