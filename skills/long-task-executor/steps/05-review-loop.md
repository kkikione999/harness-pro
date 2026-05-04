# Step 5 — Review Loop

Goal: cycle reviewer ↔ fix-worker until the reviewer returns PASS. **No fixed iteration cap.** Escalate to the user if you genuinely cannot make progress, but do not auto-stop after N tries.

## The loop

```
spawn reviewer
   │
   └─► PASS  → continue to Step 6
       FAIL  → spawn fix-worker with reviewer's findings
                  │
                  └─► spawn reviewer again
```

Repeat until PASS.

## How to spawn the reviewer

Use `Agent` with `subagent_type: "reviewer"`. The spawn prompt:

- **Approved restatement** — so the reviewer knows the actual goal, not just the diff
- **Plan file path** — so the reviewer can check spec compliance
- **Diff** — `git diff` output, or a list of changed files if the diff is large
- **Project conventions location** — CLAUDE.md path, AGENTS.md path, etc.

The reviewer returns a graded result: **PASS** / **MEDIUM** / **HIGH** / **CRITICAL**, with a list of issues.

| Grade | Action |
|-------|--------|
| PASS | Continue to Step 6 |
| MEDIUM | Note the issues, but continue (medium issues are acceptable trade-offs) |
| HIGH | Spawn fix-worker, then re-review |
| CRITICAL | Spawn fix-worker, then re-review (and consider re-planning if it's a structural issue) |

## How to spawn the fix-worker

Same agent definition (`./agents/worker.md` plugin-bundled), but the prompt is scoped to the reviewer's findings:

```
You are a worker sub-agent. Load the agent definition at ./agents/worker.md (plugin-bundled).

# Context
This is a fix iteration. The reviewer flagged the following issues
in the previous round of work:

[paste reviewer's issue list, file:line references included]

# Your task
Fix exactly these issues. Do not make unrelated changes.
Do not refactor. Do not "improve" code that wasn't flagged.

# Post-conditions
- Each flagged issue is resolved
- No new files outside the originally-changed set
- Tests still pass (or fail no more than before — teammate will verify later)
```

## When to escalate instead of looping

The loop runs until PASS, but you should escalate to the user (not silently give up) if:

- The same issue is flagged in 3 consecutive review rounds — the worker can't fix it, the plan may be wrong, or the reviewer may be wrong
- The diff is shrinking or oscillating (worker keeps undoing/redoing) — usually means conflicting constraints
- The reviewer flags a CRITICAL issue that requires re-planning, not just patching

When you escalate, summarize:
1. What the reviewer keeps flagging
2. What the worker tried in each round
3. What you think is going wrong
4. Two or three options for the user to pick from

Then wait for the user's direction.

## Why no cap

A fixed cap teaches the system that "third attempt looks okay" is good enough, even when it isn't. Better to make slow real progress and ask for help when stuck than to ship code that passed a numerical threshold but not a quality one. See `references/review-loop.md` for the longer reasoning.
