# Memory System

The executor maintains three types of memory to enable learning and improvement.

## Three Memory Types

| Type | Location | Purpose | Example |
|------|----------|---------|---------|
| **Episodic** | `harness/memory/episodic/` | Record specific events and lessons | "macOS /var is symlink to /private/var" |
| **Procedural** | `harness/memory/procedural/` | Record successful operation patterns | "Add API endpoint: 5-step workflow" |
| **Failure** | `harness/trace/failures/` | Record failure patterns for Critic | "Cache layer violated 7x in past week" |

## Episodic Memory

**What**: Specific events, contextual lessons, non-obvious observations.

**Where**: `harness/memory/episodic/`

**Format**:
```markdown
# Episode: {timestamp}-{title}

## Context
{When this happened, what project state}

## Lesson
{What was learned}

## Impact
{How this changes future behavior}
```

**When to write**:
-发现 architecture decisions that aren't in docs
- 发现 non-obvious constraints or quirks
- 发现 patterns that should be documented

## Procedural Memory

**What**: Successful operation patterns that can be reused.

**Where**: `harness/memory/procedural/`

**Format**:
```markdown
# Procedure: {task-type}

## When to Use
{Which tasks this pattern applies to}

## Steps
1. {Step 1}
2. {Step 2}
3. {Step 3}

## Success Rate
{X}/Y successful executions

## Last Validated
{date}
```

**When to write**:
- Same task executed successfully 3+ times
- Steps are consistent enough to be scripted
- Can be compiled into deterministic script

## Failure Memory

**What**: Repeated failure patterns for analysis by Critic.

**Where**: `harness/trace/failures/`

**Format**:
```json
{
  "timestamp": "2026-04-19T10:30:00Z",
  "task": "{task-name}",
  "error_type": "layer_violation|circular_dependency|test_failure|build_failure",
  "error_message": "{full error}",
  "attempted_fixes": ["{fix attempt 1}", "{fix attempt 2}"],
  "resolved": false,
  "resolution": null,
  "context_turns_at_failure": 42
}
```

`resolution` is set to `null` on initial write. If a human later fixes the issue, update to `"{how it was fixed}"` and set `resolved: true`. `context_turns_at_failure` records how deep into the context budget the failure occurred, enabling Critic to distinguish budget-exhaustion from fundamental errors.

**When to write**:
- Same error occurs 2+ times
- Error required human intervention
- Error reveals missing lint rule

## Critic → Refiner Loop

```
Executor fails
    ↓
Failure written to harness/trace/failures/
    ↓
Critic (periodic job) analyzes patterns
    ↓
If pattern found (e.g., "cache layer violated 7x"):
    ↓
Refiner updates:
    - lint-deps rules (add missing packages)
    - Error messages (make clearer)
    - Documentation (add missing rules)
    ↓
Next executor benefits from improved rules
```

## Memory Index

`harness/memory/INDEX.md` provides a quick-scan summary of all memories. Executor reads this first, then loads only relevant files.

```markdown
# Memory Index

## Procedural (Successful Patterns)
- [add-api-endpoint](procedural/add-api-endpoint.md) — 5-step flow, 7/8 success, last: 2026-04-18
- [add-database-model](procedural/add-database-model.md) — 4-step flow, 3/3 success, last: 2026-04-15 ← READY TO COMPILE

## Episodic (Lessons)
- [macos-symlink](episodic/macos-symlink.md) — /var is symlink, affects path comparison
- [test-isolation](episodic/test-isolation.md) — Shared state causes flaky tests in services/

## Recent Failures (Last 7 days)
- [cache-layer-violation](../trace/failures/2026-04-17-cache-import.json) — 3 occurrences, root cause: missing lint mapping
```

## Memory Lookup

Before starting a task, executor should check:

1. **INDEX.md**: Quick scan for relevant patterns and recent failures
2. **Procedural memory**: Load specific procedure if task type matches
3. **Episodic memory**: Check for lessons related to affected modules
4. **Recent failures**: Avoid known pitfalls

```bash
# Step 1: Read index
cat harness/memory/INDEX.md

# Step 2: Load specific memory if relevant
cat harness/memory/procedural/{task-type}.md

# Step 3: Check recent failures for affected modules
grep "{related-package}" harness/trace/failures/*.json
```

## Trajectory Compilation Trigger

When a procedural memory entry reaches **3+ successful executions with consistent steps**, the COMPLETE phase should:

1. Flag the pattern as `← READY TO COMPILE` in INDEX.md
2. Prompt user: "Pattern '{task-type}' succeeded {N}×. Compile to script?"
3. If confirmed, generate script skeleton at `scripts/{task-type}.sh`
4. Update procedural memory: mark as `compiled → scripts/{task-type}.sh`

Subsequent executions check for compiled scripts first. If script exists, run it directly. If script fails, fall back to agent execution.
