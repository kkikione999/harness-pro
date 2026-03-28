# ExecPlan Lifecycle Contract

## Scope
This contract defines mandatory lifecycle states, transition gates, merge evidence invariants, and stagnation-exit behavior for each ExecPlan.

## Roles
- Main: orchestration, state transition control, evidence verification, completion gate.
- Worker/merge flow script: sync, rebase/merge, revalidate, final merge, merge evidence writeback.

## Mandatory States
1. `IN_DEV`
2. `AUDIT_PENDING`
3. `AUDIT_PASS`
4. `MERGE_REQUIRED`
5. `MERGED`
6. `BLOCKED`
7. `FEATURE_DONE`
8. `FEATURE_BLOCKED_EXIT`

## Mandatory Runtime Fields
The orchestrator state file MUST preserve these fields across cycles:
- `TOTAL_CYCLES_COUNT`
- `LAST_STATE`
- `LAST_FEATURE_HEAD_SHA`
- `LAST_CHECKLIST_CHECKED_COUNT`
- `STAGNATION_CYCLES_COUNT`
- `LAST_PROGRESS_EPOCH`
- `MINUTES_WITHOUT_PROGRESS`

Merge flow MUST write these evidence fields:
- `MERGED_COMMIT_SHA`
- `MERGED_FEATURE_TIP_SHA`
- `MERGED_TARGET_BRANCH`
- `MERGE_EVIDENCE_VERSION`

## Transition Rules
- `AUDIT_PASS` MUST immediately transition to `MERGE_REQUIRED` in the same orchestration cycle.
- `MERGE_REQUIRED` MUST execute this chain at least once:
  - `sync`
  - `rebase/merge`
  - `revalidate`
  - `merge`
- `AUDIT_PASS` is never a completion state.

## Progress Signals (for stagnation detection)
Progress MUST be detected from multiple sources, at minimum:
- state change (`STATE` vs `LAST_STATE`)
- checklist growth (`CHECKLIST_CHECKED_COUNT` increase)
- feature branch head change (`LAST_FEATURE_HEAD_SHA` vs current feature head)

If no progress is detected in a cycle, `STAGNATION_CYCLES_COUNT` MUST increase.

## Completion Invariants
`FEATURE_DONE` is legal only when all checks pass:
- current `STATE` is `MERGED`
- `MERGED_FEATURE_TIP_SHA` is an ancestor of `MERGED_COMMIT_SHA`
- `MERGED_COMMIT_SHA` is an ancestor of current `TARGET_BRANCH` HEAD
- merge evidence fields are present (`MERGED_FEATURE_TIP_SHA`, `MERGED_TARGET_BRANCH`, `MERGE_EVIDENCE_VERSION`)

If any completion gate fails, state MUST become `BLOCKED` and `LAST_ERROR` MUST be written.

## Blocked Exit Invariants
`FEATURE_BLOCKED_EXIT` MUST:
- emit `EXIT_SIGNAL=FEATURE_BLOCKED_EXIT`
- generate `BLOCK_REPORT`
- run cleanup (unless debug-only skip is explicitly used)
- write evidence and cleanup events to `logs/orchestrator/*.jsonl`

## Audit Logging
All key actions MUST be appended to `logs/orchestrator/*.jsonl`, including:
- state transitions
- progress/stagnation decisions
- merge flow start/finish/failure
- completion gate decisions
- blocked exit decisions
- cleanup execution
