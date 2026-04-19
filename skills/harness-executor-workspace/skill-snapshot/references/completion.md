# Completion: Git, Trajectory Compilation, and Self-Repair

## Git Operations

After all validations and review pass, commit the changes:

```bash
# 1. Stage changed files (be specific, not git add -A)
git add {specific-files}

# 2. Commit with conventional format
git commit -m "<type>: <description>"

# 3. For worktree tasks: push and optionally create PR
git push -u origin {branch-name}
# Optionally: gh pr create --title "..." --body "..."
```

### Commit Message Format
Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

### Branch Strategy
| Complexity | Branch Strategy |
|-----------|----------------|
| Simple | Direct commit on current branch |
| Medium | Feature branch, commit, optionally PR |
| Complex | Worktree branch, full PR with review notes |

## Trajectory Compilation Check

Before finalizing, check if this task type is ready to be compiled into a deterministic script.

### Trigger Conditions
1. Procedural memory exists for this task type
2. Success count ≥ 3
3. Steps are consistent across executions (same order, same files affected)

### Compilation Process
```
1. Check harness/memory/INDEX.md for this task type
2. If marked ← READY TO COMPILE:
   → Prompt user: "Pattern '{task-type}' succeeded {N}×. Compile to script?"
   → If confirmed: generate scripts/{task-type}.sh
   → Update INDEX.md: mark as compiled
3. Subsequent executions check for compiled scripts first
   → Script exists? Run it directly.
   → Script fails? Fall back to agent execution.
```

### Compiled Script Skeleton
```bash
#!/bin/bash
# Auto-compiled from trajectory: {task-type}
# Success rate: {N}/{M}, last validated: {date}

set -e
# Step 1: {description}
# Step 2: {description}
# Step 3: {description}
# Validate
./scripts/validate.py
```

## Self-Repair Loop (Context-Budget Aware)

When validation fails, attempt automated repair before escalating.

### Repair Flow
```
Validation failed
    ↓
Analyze error → Fix → Re-validate
    ↓
Check context budget: {turns} / 60 tool calls used
    ↓
┌──────────────────────────────────────────────────┐
│ Continue if: turns < 40 AND error is new         │
│ Early-stop if: turns ≥ 40 OR same error repeats  │
└──────────────────────────────────────────────────┘
    ↓
Max 3 attempts, BUT early-stop if context saturated
    ↓
If stopped (3 attempts OR context saturated):
    → STOP and escalate to human
    → Save failure to harness/trace/failures/
    → Report: "Blocker at {step}: {error}. Manual intervention required."
```

### Context Budget Rule

After ~40 tool calls, critical information starts being compressed. The repair loop must respect this hard limit and escalate early rather than risk the agent "forgetting" its original objective.

Signs of context saturation:
- Re-introducing previously fixed issues
- Losing track of the original task goal
- Proposing changes that contradict earlier architecture decisions
- Repeating the same fix attempt with minor variations

### Incremental Repair

Don't re-run the full validation pipeline on each repair attempt. Only re-run the step that failed and any downstream steps that depend on it.

| Failed Step | Re-run |
|------------|--------|
| Build | build → test |
| lint-deps | lint-deps → build → test |
| lint-quality | lint-quality (only) |
| Test | test (affected package only) |
| Verify | verify (only) |

### Failure Record Format

```json
{
  "timestamp": "2026-04-19T10:30:00Z",
  "task": "{task-name}",
  "error_type": "layer_violation|circular_dependency|test_failure|build_failure",
  "error_message": "{full error}",
  "attempted_fixes": ["{fix 1}", "{fix 2}"],
  "resolved": false,
  "context_turns_at_failure": 42
}
```
