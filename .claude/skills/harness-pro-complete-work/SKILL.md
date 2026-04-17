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

Run all verification commands NOW (not from cache, not from memory).

### Discover project commands

Read `CLAUDE.md` and extract test/lint/build commands from the Development section. These are command strings only — the rules themselves live in the project's tooling.

If CLAUDE.md doesn't specify a command, check for common patterns:
- `package.json` → test: `npm test`, lint: `npm run lint`, build: `npm run build`
- `Makefile` → test: `make test`, lint: `make lint`, build: `make build`
- `*.xcodeproj` → test: `xcodebuild test -scheme {name} -destination '...'`, build: `xcodebuild build`
- `go.mod` → test: `go test ./...`, build: `go build ./...`
- `pyproject.toml` → test: `pytest`, lint: `ruff check .`

### Verification checklist

| Check | How to discover | Must pass? |
|-------|-----------------|-----------|
| P0 universal | `bash .claude/skills/harness-pro-execute-task/scripts/p0-checks.sh` | Yes |
| Tests | CLAUDE.md → Development section | Yes |
| Lint | CLAUDE.md → Development section (skip if not found) | Yes (if exists) |
| Build | CLAUDE.md → Development section (skip if not found) | Yes (if exists) |

Run P0 checks first — they're the cheapest and catch the most important violations.

### What counts as "passing"

- P0: exit code 0
- Tests: exit code 0, 0 failures in output
- Lint: exit code 0, 0 errors (warnings are OK)
- Build: exit code 0

If any check fails: **fix it first, then re-run from scratch.** Do not claim completion with failing checks.

State only verified facts: "xcodebuild test exited 0 with 7 tests passing" or "eslint found 0 errors, 2 warnings". No "should", "probably", "seems to".

## Step 2: Documentation Maintenance Check

**Any change that touches existing features must update their documentation.**

1. Did this work modify any existing feature?
   - Read `docs/features/` to see which features exist
   - Compare changed files against feature `code_scope_hint` entries

2. For each affected feature, check:
   - Does `index.md` still accurately describe the scope? → Update if scope changed
   - Does `plan.md` reflect the current state? → Update if implementation diverged
   - Are `acceptance_criteria` still valid? → Update if new behaviors were added

3. If new files were created that belong to an existing feature:
   - Update `code_scope_hint` if naming patterns expanded

**Principle: docs/features/ is the source of truth. If it rots, the entire system degrades.**

## Step 2.5: ARCHITECTURE.md Auto-Update

Read `.harness/file-stack/{feature-id}/context.md` and check `## Worker Discoveries` for architectural findings.

**Auto-update conditions** (update if ALL true):
- Feature is the first feature implemented (or Architecture is empty)
- OR discoveries contain new architectural patterns (new layers, dependency rules, entry points)

**Update scope** (conservative — only add, rarely modify):
- Add new patterns found to ## 分层结构
- Add new dependency rules to ## 依赖规则
- Add new entry points to ## 入口点
- Add new feature to ## Feature 概览

**Do NOT auto-update** for:
- CLAUDE.md changes (these require user confirmation via decompose-requirement)
- Minor implementation details
- Refactoring-only changes

**Format for updates**:
```markdown
## 分层结构
<!-- 在现有内容后追加，不要覆盖 -->
- {layer-name}: {brief description} (discovered in {feature-id})
```

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
  Check docs/features/ against actual changes
  Update index.md / plan.md if needed
        ↓
Step 2.5: ARCHITECTURE.md Auto-Update
  Read context.md discoveries
  If architectural findings → update ARCHITECTURE.md (only add, rarely modify)
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
