# Checkpoint System

Checkpoints save execution state at key phases, enabling recovery if interrupted.

## When to Save Checkpoints

| Phase | Checkpoint Name | Content |
|-------|----------------|---------|
| After context loaded | `phase-1-context-loaded` | Task, files read, layer map |
| After plan approved | `phase-2-plan-approved` | Execution plan, human approval |
| After execution complete | `phase-3-execution-complete` | Changes made, validation status |
| After all validations pass | `phase-4-validated` | Final state, memory to write |
| After cross-review pass | `phase-5-reviewed` | Review result, fixes if any |

## Checkpoint Location

```
harness/trace/checkpoints/
└── {task-name}/
    ├── phase-1-context-loaded.json
    ├── phase-2-plan-approved.json
    ├── phase-3-execution-complete.json
    ├── phase-4-validated.json
    └── phase-5-reviewed.json
```

## Checkpoint Format

```json
{
  "task": "{task-name}",
  "phase": "phase-1-context-loaded",
  "timestamp": "2026-04-19T10:30:00Z",
  "context": {
    "objective": "{what we're building}",
    "files_read": ["AGENTS.md", "docs/ARCHITECTURE.md"],
    "layer_map": {
      "types/": 0,
      "utils/": 1,
      "services/": 3,
      "handlers/": 4
    }
  },
  "architecture_decisions": [
    "Using protocol-based dependency injection",
    "Keeping types in layer 0"
  ]
}
```

## Recovery Process

```
Executor restarted after interruption
    ↓
Check harness/trace/checkpoints/{task-name}/
    ↓
Find most recent phase complete
    ↓
Load checkpoint state
    ↓
Ask human: "Resume from {phase}? (Y/n)"
    ↓
If Y: Resume from checkpoint
If N: Start fresh (but preserve checkpoint for reference)
```

## What Makes a Good Checkpoint

1. **Atomic** — Either complete or not written (use temp file + rename)
2. **Sufficient** — Enough context to understand current state
3. **Minimal** — Only critical state, not full project snapshot
4. **Recoverable** — Human can understand and override if needed

## Anti-Patterns

❌ **Don't checkpoint everything** — Large state pollutes context
❌ **Don't checkpoint too often** — Performance overhead
❌ **Don't checkpoint binary files** — Hard to merge/compare

✅ **Checkpoint decisions, not artifacts** — What was decided, not every file
✅ **Checkpoint at decision points** — After human approval, after execution
