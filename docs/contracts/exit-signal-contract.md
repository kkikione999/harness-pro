# Exit Signal Contract

## Allowed Exit Signals
- `FEATURE_DONE`
- `FEATURE_BLOCKED_EXIT`

## Priority
When multiple blocked-exit rules are true in the same cycle:
1. checklist `>=95%` stagnation rule
2. global no-progress stagnation rule

## FEATURE_DONE
### Preconditions (all mandatory)
- current `STATE` is `MERGED`
- `MERGED_COMMIT_SHA` exists in git
- `MERGED_FEATURE_TIP_SHA` exists in git
- `MERGED_TARGET_BRANCH` equals `TARGET_BRANCH`
- `MERGE_EVIDENCE_VERSION` is present
- `MERGED_FEATURE_TIP_SHA` is an ancestor of `MERGED_COMMIT_SHA`
- `MERGED_COMMIT_SHA` is an ancestor of current `TARGET_BRANCH` HEAD

### Failure behavior
If any precondition fails:
- set `STATE=BLOCKED`
- clear/keep exit signal empty
- write `LAST_ERROR`
- reject completion

### Side Effects (on success)
- emit `EXIT_SIGNAL=FEATURE_DONE`
- execute closeout cleanup
- write cleanup + completion evidence to audit log

## FEATURE_BLOCKED_EXIT
### Trigger A (checklist >=95 stagnation)
All conditions must be true:
- `FEATURE_CHECKLIST_PERCENT >= 95`
- stagnation window reached:
  - default `STAGNATION_CYCLES_COUNT >= 3`
  - default `MINUTES_WITHOUT_PROGRESS >= 120`

### Trigger B (global no-progress guard)
All conditions must be true:
- no progress across required signals (state/checklist/feature head)
- global stagnation window reached:
  - default `STAGNATION_CYCLES_COUNT >= 8`
  - default `MINUTES_WITHOUT_PROGRESS >= 360`

### Side Effects
- emit `EXIT_SIGNAL=FEATURE_BLOCKED_EXIT`
- generate `BLOCK_REPORT`
- execute closeout cleanup
- write exit/report/cleanup events to audit log

## Forbidden
- direct completion from `AUDIT_PASS`
- `FEATURE_DONE` without merge evidence chain
- bypassing merge chain by writing a forged `MERGED_COMMIT_SHA` only
