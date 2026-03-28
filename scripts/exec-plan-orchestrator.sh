#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(pwd)"
STATE_FILE=""
FEATURE_BRANCH_ARG=""
TARGET_BRANCH_ARG=""
VALIDATION_CMD_ARG=""
AUDIT_RESULT_ARG=""
CHECKLIST_PERCENT_ARG=""
CHECKLIST_COUNT_ARG=""
MARK_FEATURE_DONE=0
STAGNATION_CYCLES_THRESHOLD_ARG=""
STAGNATION_MINUTES_THRESHOLD_ARG=""
GLOBAL_STAGNATION_CYCLES_THRESHOLD_ARG=""
GLOBAL_STAGNATION_MINUTES_THRESHOLD_ARG=""
BLOCK_REPORT_FORMAT="json"
BLOCK_ID_ARG=""
BLOCK_REASON_ARG=""
BLOCK_IMPACT_ARG=""
BLOCK_RECOMMENDATION_ARG=""
NOW_EPOCH_ARG=""
LOG_FILE_ARG=""
SKIP_CLEANUP=0
BLOCK_ID_OVERRIDDEN=0
BLOCK_REASON_OVERRIDDEN=0
BLOCK_IMPACT_OVERRIDDEN=0

usage() {
  cat <<USAGE
Usage: $0 --state-file <file> [options]

Options:
  --repo-root <dir>
  --feature-branch <name>
  --target-branch <name>
  --validation-cmd <cmd>
  --audit-result <AUDIT_PENDING|AUDIT_PASS|AUDIT_FAIL>
  --checklist-percent <int>
  --checklist-count <int>
  --mark-feature-done
  --stagnation-cycles <int>             (checklist >=95 rule, default: 3)
  --stagnation-minutes <int>            (checklist >=95 rule, default: 120)
  --global-stagnation-cycles <int>      (global no-progress rule, default: 8)
  --global-stagnation-minutes <int>     (global no-progress rule, default: 360)
  --block-report-format <json|md>
  --block-id <id>
  --block-reason <text>
  --block-impact <text>
  --block-recommendation <text>
  --log-file <path>
  --now-epoch <unix-epoch>
  --skip-cleanup
USAGE
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

log_event() {
  local event="$1"
  local detail="${2:-}"
  mkdir -p "$(dirname "$LOG_FILE")"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf '{"ts":"%s","execplan_id":"%s","event":"%s","state":"%s","detail":"%s"}\n' \
    "$ts" "$(json_escape "$EXECPLAN_ID")" "$(json_escape "$event")" "$(json_escape "$STATE")" "$(json_escape "$detail")" \
    >> "$LOG_FILE"
}

is_allowed_state() {
  case "$1" in
    IN_DEV|AUDIT_PENDING|AUDIT_PASS|MERGE_REQUIRED|MERGED|BLOCKED|FEATURE_DONE|FEATURE_BLOCKED_EXIT)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

resolve_feature_head_sha() {
  local branch="$1"
  if [[ -z "$branch" ]]; then
    return 0
  fi
  git -C "$REPO_ROOT" rev-parse --verify "$branch" 2>/dev/null || true
}

transition_state() {
  local new_state="$1"
  local reason="$2"
  if [[ "$STATE" == "$new_state" ]]; then
    return
  fi
  local previous_state="$STATE"
  STATE="$new_state"
  log_event "state_transition" "${previous_state}->${new_state} (${reason})"
}

write_state_file() {
  mkdir -p "$(dirname "$STATE_FILE")"
  {
    printf 'EXECPLAN_ID=%q\n' "$EXECPLAN_ID"
    printf 'STATE=%q\n' "$STATE"
    printf 'FEATURE_BRANCH=%q\n' "$FEATURE_BRANCH"
    printf 'TARGET_BRANCH=%q\n' "$TARGET_BRANCH"
    printf 'VALIDATION_CMD=%q\n' "$VALIDATION_CMD"
    printf 'AUDIT_RESULT=%q\n' "$AUDIT_RESULT"
    printf 'FEATURE_CHECKLIST_PERCENT=%q\n' "$FEATURE_CHECKLIST_PERCENT"
    printf 'CHECKLIST_CHECKED_COUNT=%q\n' "$CHECKLIST_CHECKED_COUNT"
    printf 'LAST_CHECKLIST_CHECKED_COUNT=%q\n' "$LAST_CHECKLIST_CHECKED_COUNT"
    printf 'STAGNATION_CYCLES_COUNT=%q\n' "$STAGNATION_CYCLES_COUNT"
    printf 'LAST_PROGRESS_EPOCH=%q\n' "$LAST_PROGRESS_EPOCH"
    printf 'MINUTES_WITHOUT_PROGRESS=%q\n' "$MINUTES_WITHOUT_PROGRESS"
    printf 'TOTAL_CYCLES_COUNT=%q\n' "$TOTAL_CYCLES_COUNT"
    printf 'LAST_STATE=%q\n' "$LAST_STATE"
    printf 'LAST_FEATURE_HEAD_SHA=%q\n' "$LAST_FEATURE_HEAD_SHA"
    printf 'MERGED_COMMIT_SHA=%q\n' "$MERGED_COMMIT_SHA"
    printf 'MERGED_FEATURE_TIP_SHA=%q\n' "$MERGED_FEATURE_TIP_SHA"
    printf 'MERGED_TARGET_BRANCH=%q\n' "$MERGED_TARGET_BRANCH"
    printf 'MERGE_EVIDENCE_VERSION=%q\n' "$MERGE_EVIDENCE_VERSION"
    printf 'MERGE_COMPLETED_AT=%q\n' "$MERGE_COMPLETED_AT"
    printf 'EXIT_SIGNAL=%q\n' "$EXIT_SIGNAL"
    printf 'BLOCK_REPORT_PATH=%q\n' "$BLOCK_REPORT_PATH"
    printf 'LAST_ERROR=%q\n' "$LAST_ERROR"
    printf 'CLEANUP_DONE=%q\n' "$CLEANUP_DONE"
    printf 'UPDATED_AT_UTC=%q\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  } > "$STATE_FILE"
}

reload_state_file() {
  # shellcheck disable=SC1090
  source "$STATE_FILE"
}

create_block_report() {
  local report_ext
  if [[ "$BLOCK_REPORT_FORMAT" == "md" ]]; then
    report_ext="md"
  else
    report_ext="json"
  fi

  local report_dir="$REPO_ROOT/logs/orchestrator/block-reports"
  mkdir -p "$report_dir"
  local report_ts
  report_ts="$(date -u +"%Y%m%dT%H%M%SZ")"
  BLOCK_REPORT_PATH="$report_dir/${EXECPLAN_ID}-${report_ts}.${report_ext}"

  local blocked_at
  blocked_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local recommendation
  recommendation="${BLOCK_RECOMMENDATION:-Escalate blocker owner; split unresolved task; rerun orchestration after unblock}"

  if [[ "$report_ext" == "md" ]]; then
    cat > "$BLOCK_REPORT_PATH" <<MD
# BLOCK_REPORT

- execplan_id: \
  ${EXECPLAN_ID}
- signal: FEATURE_BLOCKED_EXIT
- blocked_at: ${blocked_at}
- checkpoint_id: ${BLOCK_ID}
- reason: ${BLOCK_REASON}
- evidence:
  - feature_checklist_percent: ${FEATURE_CHECKLIST_PERCENT}
  - checklist_checked_count: ${CHECKLIST_CHECKED_COUNT}
  - previous_checked_count: ${LAST_CHECKLIST_CHECKED_COUNT}
  - stagnation_cycles: ${STAGNATION_CYCLES_COUNT}
  - minutes_without_progress: ${MINUTES_WITHOUT_PROGRESS}
  - total_cycles_count: ${TOTAL_CYCLES_COUNT}
  - last_state: ${LAST_STATE}
  - last_feature_head_sha: ${LAST_FEATURE_HEAD_SHA}
- impact: ${BLOCK_IMPACT}
- recommendation: ${recommendation}
- attachments:
  - ${LOG_FILE}
MD
  else
    cat > "$BLOCK_REPORT_PATH" <<JSON
{
  "execplan_id": "${EXECPLAN_ID}",
  "signal": "FEATURE_BLOCKED_EXIT",
  "blocked_at": "${blocked_at}",
  "checkpoint_id": "${BLOCK_ID}",
  "reason": "${BLOCK_REASON}",
  "evidence": {
    "feature_checklist_percent": ${FEATURE_CHECKLIST_PERCENT},
    "checklist_checked_count": ${CHECKLIST_CHECKED_COUNT},
    "previous_checked_count": ${LAST_CHECKLIST_CHECKED_COUNT},
    "stagnation_cycles": ${STAGNATION_CYCLES_COUNT},
    "minutes_without_progress": ${MINUTES_WITHOUT_PROGRESS},
    "total_cycles_count": ${TOTAL_CYCLES_COUNT},
    "last_state": "${LAST_STATE}",
    "last_feature_head_sha": "${LAST_FEATURE_HEAD_SHA}"
  },
  "impact": "${BLOCK_IMPACT}",
  "recommendation": [
    "${recommendation}"
  ],
  "attachments": [
    "${LOG_FILE}"
  ]
}
JSON
  fi

  log_event "block_report_written" "$BLOCK_REPORT_PATH"
}

run_cleanup_if_needed() {
  if [[ "$SKIP_CLEANUP" -eq 1 ]]; then
    log_event "cleanup_skipped" "skip requested (debug only)"
    return
  fi

  if [[ "$CLEANUP_DONE" == "1" ]]; then
    log_event "cleanup_already_done" "state says cleanup already done"
    return
  fi

  log_event "cleanup_start" "feature closeout cleanup"
  local cleanup_output
  cleanup_output="$($SCRIPT_DIR/feature-closeout-cleanup.sh --repo-root "$REPO_ROOT" --log-file "$LOG_FILE" | tr '\n' ' ' | sed 's/  */ /g; s/ $//')"
  log_event "cleanup_done" "$cleanup_output"
  CLEANUP_DONE="1"
}

emit_blocked_exit() {
  local error_code="$1"
  local detail="$2"

  STATE="FEATURE_BLOCKED_EXIT"
  EXIT_SIGNAL="FEATURE_BLOCKED_EXIT"
  LAST_ERROR="$error_code"
  LAST_STATE="$STATE"
  LAST_FEATURE_HEAD_SHA="$CURRENT_FEATURE_HEAD_SHA"

  log_event "exit_signal" "$detail"
  create_block_report
  write_state_file
  run_cleanup_if_needed
  LAST_STATE="$STATE"
  LAST_FEATURE_HEAD_SHA="$CURRENT_FEATURE_HEAD_SHA"
  write_state_file

  printf 'state=%s\n' "$STATE"
  printf 'exit_signal=%s\n' "$EXIT_SIGNAL"
  printf 'block_report=%s\n' "$BLOCK_REPORT_PATH"
  exit 0
}

reject_feature_done() {
  local code="$1"
  local detail="$2"
  local message="$3"

  STATE="BLOCKED"
  EXIT_SIGNAL=""
  LAST_ERROR="$code"
  LAST_STATE="$STATE"
  LAST_FEATURE_HEAD_SHA="$CURRENT_FEATURE_HEAD_SHA"
  log_event "completion_rejected" "$detail"
  write_state_file
  echo "$message" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --state-file)
      STATE_FILE="$2"
      shift 2
      ;;
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --feature-branch)
      FEATURE_BRANCH_ARG="$2"
      shift 2
      ;;
    --target-branch)
      TARGET_BRANCH_ARG="$2"
      shift 2
      ;;
    --validation-cmd)
      VALIDATION_CMD_ARG="$2"
      shift 2
      ;;
    --audit-result)
      AUDIT_RESULT_ARG="$2"
      shift 2
      ;;
    --checklist-percent)
      CHECKLIST_PERCENT_ARG="$2"
      shift 2
      ;;
    --checklist-count)
      CHECKLIST_COUNT_ARG="$2"
      shift 2
      ;;
    --mark-feature-done)
      MARK_FEATURE_DONE=1
      shift
      ;;
    --stagnation-cycles)
      STAGNATION_CYCLES_THRESHOLD_ARG="$2"
      shift 2
      ;;
    --stagnation-minutes)
      STAGNATION_MINUTES_THRESHOLD_ARG="$2"
      shift 2
      ;;
    --global-stagnation-cycles)
      GLOBAL_STAGNATION_CYCLES_THRESHOLD_ARG="$2"
      shift 2
      ;;
    --global-stagnation-minutes)
      GLOBAL_STAGNATION_MINUTES_THRESHOLD_ARG="$2"
      shift 2
      ;;
    --block-report-format)
      BLOCK_REPORT_FORMAT="$2"
      shift 2
      ;;
    --block-id)
      BLOCK_ID_ARG="$2"
      BLOCK_ID_OVERRIDDEN=1
      shift 2
      ;;
    --block-reason)
      BLOCK_REASON_ARG="$2"
      BLOCK_REASON_OVERRIDDEN=1
      shift 2
      ;;
    --block-impact)
      BLOCK_IMPACT_ARG="$2"
      BLOCK_IMPACT_OVERRIDDEN=1
      shift 2
      ;;
    --block-recommendation)
      BLOCK_RECOMMENDATION_ARG="$2"
      shift 2
      ;;
    --now-epoch)
      NOW_EPOCH_ARG="$2"
      shift 2
      ;;
    --log-file)
      LOG_FILE_ARG="$2"
      shift 2
      ;;
    --skip-cleanup)
      SKIP_CLEANUP=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "$STATE_FILE" ]]; then
  echo "--state-file is required" >&2
  exit 1
fi

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  echo "Not a git repository: $REPO_ROOT" >&2
  exit 1
fi

REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"

# defaults
EXECPLAN_ID="execplan-$(date +%s)"
STATE="IN_DEV"
FEATURE_BRANCH=""
TARGET_BRANCH="main"
VALIDATION_CMD=":"
AUDIT_RESULT=""
FEATURE_CHECKLIST_PERCENT="0"
CHECKLIST_CHECKED_COUNT="0"
LAST_CHECKLIST_CHECKED_COUNT="0"
STAGNATION_CYCLES_COUNT="0"
LAST_PROGRESS_EPOCH="$(date +%s)"
MINUTES_WITHOUT_PROGRESS="0"
TOTAL_CYCLES_COUNT="0"
LAST_STATE="IN_DEV"
LAST_FEATURE_HEAD_SHA=""
MERGED_COMMIT_SHA=""
MERGED_FEATURE_TIP_SHA=""
MERGED_TARGET_BRANCH=""
MERGE_EVIDENCE_VERSION=""
MERGE_COMPLETED_AT=""
EXIT_SIGNAL=""
BLOCK_REPORT_PATH=""
LAST_ERROR=""
CLEANUP_DONE="0"
BLOCK_RECOMMENDATION="Escalate blocker owner; split unresolved task; rerun orchestration after unblock"
BLOCK_ID="BLK-STAGNATION-95"
BLOCK_REASON="Checklist >=95% and no new checks in stagnation window"
BLOCK_IMPACT="Feature cannot be safely completed in current cycle"
GLOBAL_BLOCK_ID="BLK-GLOBAL-STAGNATION"
GLOBAL_BLOCK_REASON="No progress in state/checklist/feature head within global stagnation window"
GLOBAL_BLOCK_IMPACT="ExecPlan cannot make forward progress in current cycle"

if [[ -f "$STATE_FILE" ]]; then
  reload_state_file
fi

if [[ -n "$FEATURE_BRANCH_ARG" ]]; then FEATURE_BRANCH="$FEATURE_BRANCH_ARG"; fi
if [[ -n "$TARGET_BRANCH_ARG" ]]; then TARGET_BRANCH="$TARGET_BRANCH_ARG"; fi
if [[ -n "$VALIDATION_CMD_ARG" ]]; then VALIDATION_CMD="$VALIDATION_CMD_ARG"; fi
if [[ -n "$AUDIT_RESULT_ARG" ]]; then AUDIT_RESULT="$AUDIT_RESULT_ARG"; fi
if [[ -n "$CHECKLIST_PERCENT_ARG" ]]; then FEATURE_CHECKLIST_PERCENT="$CHECKLIST_PERCENT_ARG"; fi
if [[ -n "$CHECKLIST_COUNT_ARG" ]]; then CHECKLIST_CHECKED_COUNT="$CHECKLIST_COUNT_ARG"; fi
if [[ -n "$BLOCK_ID_ARG" ]]; then BLOCK_ID="$BLOCK_ID_ARG"; fi
if [[ -n "$BLOCK_REASON_ARG" ]]; then BLOCK_REASON="$BLOCK_REASON_ARG"; fi
if [[ -n "$BLOCK_IMPACT_ARG" ]]; then BLOCK_IMPACT="$BLOCK_IMPACT_ARG"; fi
if [[ -n "$BLOCK_RECOMMENDATION_ARG" ]]; then BLOCK_RECOMMENDATION="$BLOCK_RECOMMENDATION_ARG"; fi

STAGNATION_CYCLES_THRESHOLD="${STAGNATION_CYCLES_THRESHOLD_ARG:-${STAGNATION_CYCLES_THRESHOLD:-3}}"
STAGNATION_MINUTES_THRESHOLD="${STAGNATION_MINUTES_THRESHOLD_ARG:-${STAGNATION_MINUTES_THRESHOLD:-120}}"
GLOBAL_STAGNATION_CYCLES_THRESHOLD="${GLOBAL_STAGNATION_CYCLES_THRESHOLD_ARG:-${GLOBAL_STAGNATION_CYCLES_THRESHOLD:-8}}"
GLOBAL_STAGNATION_MINUTES_THRESHOLD="${GLOBAL_STAGNATION_MINUTES_THRESHOLD_ARG:-${GLOBAL_STAGNATION_MINUTES_THRESHOLD:-360}}"

if [[ -z "$FEATURE_BRANCH" ]]; then
  FEATURE_BRANCH="feature/${EXECPLAN_ID}"
fi

if [[ -n "$LOG_FILE_ARG" ]]; then
  LOG_FILE="$LOG_FILE_ARG"
else
  LOG_FILE="$REPO_ROOT/logs/orchestrator/${EXECPLAN_ID}.jsonl"
fi

if ! is_allowed_state "$STATE"; then
  echo "Invalid state in state file: $STATE" >&2
  exit 1
fi

if [[ -n "$NOW_EPOCH_ARG" ]]; then
  NOW_EPOCH="$NOW_EPOCH_ARG"
else
  NOW_EPOCH="$(date +%s)"
fi

LAST_STATE="${LAST_STATE:-$STATE}"
LAST_FEATURE_HEAD_SHA="${LAST_FEATURE_HEAD_SHA:-}"
LAST_CHECKLIST_CHECKED_COUNT="${LAST_CHECKLIST_CHECKED_COUNT:-0}"
STAGNATION_CYCLES_COUNT="${STAGNATION_CYCLES_COUNT:-0}"
TOTAL_CYCLES_COUNT="${TOTAL_CYCLES_COUNT:-0}"
LAST_PROGRESS_EPOCH="${LAST_PROGRESS_EPOCH:-$NOW_EPOCH}"

PREV_LAST_STATE="$LAST_STATE"
PREV_LAST_FEATURE_HEAD_SHA="$LAST_FEATURE_HEAD_SHA"
PREV_LAST_CHECKLIST_CHECKED_COUNT="$LAST_CHECKLIST_CHECKED_COUNT"
TOTAL_CYCLES_COUNT=$((TOTAL_CYCLES_COUNT + 1))

case "$STATE" in
  IN_DEV)
    if [[ "$AUDIT_RESULT" == "AUDIT_PENDING" ]]; then
      transition_state "AUDIT_PENDING" "audit pending"
    elif [[ "$AUDIT_RESULT" == "AUDIT_PASS" ]]; then
      transition_state "AUDIT_PASS" "audit pass"
    fi
    ;;
  AUDIT_PENDING)
    if [[ "$AUDIT_RESULT" == "AUDIT_PASS" ]]; then
      transition_state "AUDIT_PASS" "audit pass"
    fi
    ;;
  AUDIT_PASS|MERGE_REQUIRED|MERGED|BLOCKED|FEATURE_DONE|FEATURE_BLOCKED_EXIT)
    ;;
esac

if [[ "$STATE" == "AUDIT_PASS" ]]; then
  transition_state "MERGE_REQUIRED" "audit pass requires merge flow"
  LAST_STATE="$STATE"
  LAST_FEATURE_HEAD_SHA="$(resolve_feature_head_sha "$FEATURE_BRANCH")"
  write_state_file

  if ! merged_sha="$($SCRIPT_DIR/merge-verify-writeback.sh \
      --repo-root "$REPO_ROOT" \
      --state-file "$STATE_FILE" \
      --feature-branch "$FEATURE_BRANCH" \
      --target-branch "$TARGET_BRANCH" \
      --validation-cmd "$VALIDATION_CMD" \
      --log-file "$LOG_FILE")"; then
    STATE="BLOCKED"
    EXIT_SIGNAL=""
    LAST_ERROR="merge_flow_failed"
    CURRENT_FEATURE_HEAD_SHA="$(resolve_feature_head_sha "$FEATURE_BRANCH")"
    LAST_STATE="$STATE"
    LAST_FEATURE_HEAD_SHA="$CURRENT_FEATURE_HEAD_SHA"
    log_event "state_transition" "MERGE_REQUIRED->BLOCKED (merge flow failed)"
    write_state_file
    echo "Merge flow failed" >&2
    exit 1
  fi

  reload_state_file
  MERGED_COMMIT_SHA="${MERGED_COMMIT_SHA:-$merged_sha}"
  transition_state "MERGED" "merge evidence captured"
  EXIT_SIGNAL=""
  LAST_ERROR=""
fi

CURRENT_FEATURE_HEAD_SHA="$(resolve_feature_head_sha "$FEATURE_BRANCH")"

progress_signals=""
if [[ "$CHECKLIST_CHECKED_COUNT" -gt "$PREV_LAST_CHECKLIST_CHECKED_COUNT" ]]; then
  LAST_CHECKLIST_CHECKED_COUNT="$CHECKLIST_CHECKED_COUNT"
  progress_signals="checklist"
fi

if [[ "$STATE" != "$PREV_LAST_STATE" ]]; then
  if [[ -n "$progress_signals" ]]; then
    progress_signals+="|"
  fi
  progress_signals+="state"
fi

if [[ -n "$CURRENT_FEATURE_HEAD_SHA" ]] && [[ "$CURRENT_FEATURE_HEAD_SHA" != "$PREV_LAST_FEATURE_HEAD_SHA" ]]; then
  if [[ -n "$progress_signals" ]]; then
    progress_signals+="|"
  fi
  progress_signals+="feature_head"
fi

if [[ -n "$progress_signals" ]]; then
  STAGNATION_CYCLES_COUNT=0
  LAST_PROGRESS_EPOCH="$NOW_EPOCH"
  log_event "progress_detected" "signals=$progress_signals"
else
  STAGNATION_CYCLES_COUNT=$((STAGNATION_CYCLES_COUNT + 1))
  log_event "stagnation_tick" "signals=none"
fi

if [[ "$NOW_EPOCH" -lt "$LAST_PROGRESS_EPOCH" ]]; then
  LAST_PROGRESS_EPOCH="$NOW_EPOCH"
fi

MINUTES_WITHOUT_PROGRESS=$(((NOW_EPOCH - LAST_PROGRESS_EPOCH) / 60))
LAST_STATE="$STATE"
LAST_FEATURE_HEAD_SHA="$CURRENT_FEATURE_HEAD_SHA"

if [[ "$STATE" != "FEATURE_DONE" ]] && [[ "$STATE" != "FEATURE_BLOCKED_EXIT" ]]; then
  if [[ "$FEATURE_CHECKLIST_PERCENT" -ge 95 ]] && \
     [[ "$STAGNATION_CYCLES_COUNT" -ge "$STAGNATION_CYCLES_THRESHOLD" ]] && \
     [[ "$MINUTES_WITHOUT_PROGRESS" -ge "$STAGNATION_MINUTES_THRESHOLD" ]]; then
    emit_blocked_exit "stagnation_threshold_reached" "FEATURE_BLOCKED_EXIT triggered by checklist>=95 stagnation"
  fi

  if [[ "$STAGNATION_CYCLES_COUNT" -ge "$GLOBAL_STAGNATION_CYCLES_THRESHOLD" ]] && \
     [[ "$MINUTES_WITHOUT_PROGRESS" -ge "$GLOBAL_STAGNATION_MINUTES_THRESHOLD" ]]; then
    if [[ "$BLOCK_ID_OVERRIDDEN" -eq 0 ]]; then
      BLOCK_ID="$GLOBAL_BLOCK_ID"
    fi
    if [[ "$BLOCK_REASON_OVERRIDDEN" -eq 0 ]]; then
      BLOCK_REASON="$GLOBAL_BLOCK_REASON"
    fi
    if [[ "$BLOCK_IMPACT_OVERRIDDEN" -eq 0 ]]; then
      BLOCK_IMPACT="$GLOBAL_BLOCK_IMPACT"
    fi
    emit_blocked_exit "global_stagnation_threshold_reached" "FEATURE_BLOCKED_EXIT triggered by global stagnation"
  fi
fi

if [[ "$MARK_FEATURE_DONE" -eq 1 ]]; then
  if [[ "$STATE" != "MERGED" ]]; then
    reject_feature_done "state_not_merged_for_feature_done" "state must be MERGED before FEATURE_DONE" "Cannot mark FEATURE_DONE unless STATE=MERGED"
  fi

  if [[ -z "$MERGED_COMMIT_SHA" ]]; then
    reject_feature_done "missing_merged_commit_sha" "missing merged_commit_sha" "Cannot mark FEATURE_DONE without merged_commit_sha"
  fi

  if [[ -z "$MERGED_FEATURE_TIP_SHA" ]]; then
    reject_feature_done "missing_merged_feature_tip_sha" "missing merged feature tip sha" "Cannot mark FEATURE_DONE without merged feature tip evidence"
  fi

  if [[ -z "$MERGED_TARGET_BRANCH" ]]; then
    reject_feature_done "missing_merged_target_branch" "missing merged target branch" "Cannot mark FEATURE_DONE without merged target branch evidence"
  fi

  if [[ -z "$MERGE_EVIDENCE_VERSION" ]]; then
    reject_feature_done "missing_merge_evidence_version" "missing merge evidence version" "Cannot mark FEATURE_DONE without merge evidence version"
  fi

  if [[ "$MERGED_TARGET_BRANCH" != "$TARGET_BRANCH" ]]; then
    reject_feature_done "merged_target_branch_mismatch" "state target branch evidence mismatch" "Cannot mark FEATURE_DONE: merged target branch does not match target branch"
  fi

  if ! git -C "$REPO_ROOT" rev-parse --verify "$MERGED_COMMIT_SHA" >/dev/null 2>&1; then
    reject_feature_done "merged_commit_sha_not_found" "merged_commit_sha missing in git" "merged_commit_sha not found in git history"
  fi

  if ! git -C "$REPO_ROOT" rev-parse --verify "$MERGED_FEATURE_TIP_SHA" >/dev/null 2>&1; then
    reject_feature_done "merged_feature_tip_sha_not_found" "merged feature tip missing in git" "merged feature tip sha not found in git history"
  fi

  if ! git -C "$REPO_ROOT" merge-base --is-ancestor "$MERGED_FEATURE_TIP_SHA" "$MERGED_COMMIT_SHA"; then
    reject_feature_done "merged_feature_tip_not_ancestor" "merged feature tip is not ancestor of merged commit" "Cannot mark FEATURE_DONE: merged feature tip is not ancestor of merged commit"
  fi

  if ! target_head_sha="$(git -C "$REPO_ROOT" rev-parse --verify "$TARGET_BRANCH" 2>/dev/null)"; then
    reject_feature_done "target_branch_not_found_for_completion" "target branch not found for completion verification" "Cannot mark FEATURE_DONE: target branch not found"
  fi

  if ! git -C "$REPO_ROOT" merge-base --is-ancestor "$MERGED_COMMIT_SHA" "$target_head_sha"; then
    reject_feature_done "merged_commit_not_on_target_history" "merged commit is not ancestor of target HEAD" "Cannot mark FEATURE_DONE: merged commit is not in target branch history"
  fi

  STATE="FEATURE_DONE"
  EXIT_SIGNAL="FEATURE_DONE"
  LAST_ERROR=""
  LAST_STATE="$STATE"
  LAST_FEATURE_HEAD_SHA="$CURRENT_FEATURE_HEAD_SHA"
  log_event "exit_signal" "FEATURE_DONE with merge evidence verified"
fi

if [[ "$STATE" == "FEATURE_DONE" ]] || [[ "$STATE" == "FEATURE_BLOCKED_EXIT" ]]; then
  if [[ "$STATE" == "FEATURE_DONE" ]] && [[ -z "$MERGED_COMMIT_SHA" ]]; then
    reject_feature_done "feature_done_without_merged_sha" "FEATURE_DONE requires merged_commit_sha" "FEATURE_DONE requires merged_commit_sha"
  fi
  run_cleanup_if_needed
fi

LAST_STATE="$STATE"
LAST_FEATURE_HEAD_SHA="$CURRENT_FEATURE_HEAD_SHA"
write_state_file

printf 'state=%s\n' "$STATE"
printf 'merged_commit_sha=%s\n' "$MERGED_COMMIT_SHA"
printf 'exit_signal=%s\n' "$EXIT_SIGNAL"
printf 'block_report=%s\n' "$BLOCK_REPORT_PATH"
