#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd -P)"
ORCH_SCRIPT="$REPO_ROOT/scripts/exec-plan-orchestrator.sh"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/execplan-e2e.XXXXXX")"
trap 'rm -rf "$TEST_ROOT"' EXIT

log() {
  printf '[execplan-e2e] %s\n' "$*"
}

fail() {
  printf '[execplan-e2e] FAIL: %s\n' "$*" >&2
  exit 1
}

assert_eq() {
  local actual="$1"
  local expected="$2"
  local message="$3"
  if [[ "$actual" != "$expected" ]]; then
    fail "$message (actual=$actual expected=$expected)"
  fi
}

assert_non_empty() {
  local value="$1"
  local message="$2"
  if [[ -z "$value" ]]; then
    fail "$message"
  fi
}

assert_file_exists() {
  local path="$1"
  local message="$2"
  if [[ ! -e "$path" ]]; then
    fail "$message ($path)"
  fi
}

assert_file_missing() {
  local path="$1"
  local message="$2"
  if [[ -e "$path" ]]; then
    fail "$message ($path)"
  fi
}

load_state() {
  local file="$1"
  unset EXECPLAN_ID STATE FEATURE_BRANCH TARGET_BRANCH VALIDATION_CMD AUDIT_RESULT FEATURE_CHECKLIST_PERCENT \
    CHECKLIST_CHECKED_COUNT LAST_CHECKLIST_CHECKED_COUNT STAGNATION_CYCLES_COUNT LAST_PROGRESS_EPOCH \
    MINUTES_WITHOUT_PROGRESS TOTAL_CYCLES_COUNT LAST_STATE LAST_FEATURE_HEAD_SHA MERGED_COMMIT_SHA \
    MERGED_FEATURE_TIP_SHA MERGED_TARGET_BRANCH MERGE_EVIDENCE_VERSION MERGE_COMPLETED_AT EXIT_SIGNAL \
    BLOCK_REPORT_PATH LAST_ERROR CLEANUP_DONE UPDATED_AT_UTC || true
  # shellcheck disable=SC1090
  source "$file"
}

create_repo() {
  local name="$1"
  local repo="$TEST_ROOT/$name"
  mkdir -p "$repo"

  git -C "$repo" init -q
  git -C "$repo" config user.email "execplan-e2e@example.com"
  git -C "$repo" config user.name "ExecPlan E2E"

  local current_branch
  current_branch="$(git -C "$repo" branch --show-current)"
  if [[ "$current_branch" != "main" ]]; then
    git -C "$repo" checkout -q -b main
  fi

  printf 'base\n' > "$repo/app.txt"
  git -C "$repo" add app.txt
  git -C "$repo" commit -q -m "init"

  printf '%s\n' "$repo"
}

create_feature_commit() {
  local repo="$1"
  local feature_branch="$2"
  local marker="$3"

  git -C "$repo" checkout -q -b "$feature_branch"
  printf '%s\n' "$marker" >> "$repo/app.txt"
  git -C "$repo" add app.txt
  git -C "$repo" commit -q -m "feature: $marker"
  local tip_sha
  tip_sha="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -q main

  printf '%s\n' "$tip_sha"
}

run_until_blocked_exit() {
  local repo="$1"
  local state_file="$2"
  local feature_branch="$3"
  local max_cycles=12
  local cycle=1
  local now_epoch=2000000000

  while [[ "$cycle" -le "$max_cycles" ]]; do
    "$ORCH_SCRIPT" \
      --repo-root "$repo" \
      --state-file "$state_file" \
      --feature-branch "$feature_branch" \
      --target-branch main \
      --validation-cmd ":" \
      --now-epoch "$now_epoch" \
      >/dev/null

    load_state "$state_file"
    if [[ "$STATE" == "FEATURE_BLOCKED_EXIT" ]]; then
      return 0
    fi

    cycle=$((cycle + 1))
    now_epoch=$((now_epoch + 3600))
  done

  return 1
}

test_default_stagnation_exit() {
  log "test_default_stagnation_exit"
  local repo
  repo="$(create_repo t01-default-stagnation)"
  local feature_branch="feature/stall-default"
  create_feature_commit "$repo" "$feature_branch" "stall"

  local state_file="$repo/.execplan/state.env"
  mkdir -p "$(dirname "$state_file")"
  printf 'cleanup-me\n' > "$repo/.DS_Store"

  run_until_blocked_exit "$repo" "$state_file" "$feature_branch" || fail "default global stagnation did not trigger FEATURE_BLOCKED_EXIT"

  load_state "$state_file"
  assert_eq "$STATE" "FEATURE_BLOCKED_EXIT" "state should become FEATURE_BLOCKED_EXIT"
  assert_eq "$EXIT_SIGNAL" "FEATURE_BLOCKED_EXIT" "exit signal should be FEATURE_BLOCKED_EXIT"
  assert_eq "$CLEANUP_DONE" "1" "cleanup should run on FEATURE_BLOCKED_EXIT"
  assert_non_empty "$BLOCK_REPORT_PATH" "block report path should be set"
  assert_file_exists "$BLOCK_REPORT_PATH" "block report should exist"
  assert_file_missing "$repo/.DS_Store" "blocked exit cleanup should remove junk files"
}

test_audit_pass_forces_merge() {
  log "test_audit_pass_forces_merge"
  local repo
  repo="$(create_repo t02-merge-flow)"
  local feature_branch="feature/merge-flow"
  create_feature_commit "$repo" "$feature_branch" "merge-flow"

  local state_file="$repo/.execplan/state.env"
  mkdir -p "$(dirname "$state_file")"

  "$ORCH_SCRIPT" \
    --repo-root "$repo" \
    --state-file "$state_file" \
    --feature-branch "$feature_branch" \
    --target-branch main \
    --validation-cmd ":" \
    --audit-result AUDIT_PASS \
    >/dev/null

  load_state "$state_file"
  assert_eq "$STATE" "MERGED" "AUDIT_PASS should force merge flow and reach MERGED"
  assert_non_empty "$MERGED_COMMIT_SHA" "MERGED_COMMIT_SHA should be written"
  assert_non_empty "$MERGED_FEATURE_TIP_SHA" "MERGED_FEATURE_TIP_SHA should be written"
  assert_eq "$MERGED_TARGET_BRANCH" "main" "MERGED_TARGET_BRANCH should be written"
  assert_eq "$MERGE_EVIDENCE_VERSION" "v1" "MERGE_EVIDENCE_VERSION should be written"

  git -C "$repo" rev-parse --verify "$MERGED_COMMIT_SHA" >/dev/null
}

test_forged_merged_sha_rejected() {
  log "test_forged_merged_sha_rejected"
  local repo
  repo="$(create_repo t03-forged-sha)"
  local feature_branch="feature/forged"
  local feature_tip_sha
  feature_tip_sha="$(create_feature_commit "$repo" "$feature_branch" "forged")"
  local fake_merged_sha
  fake_merged_sha="$(git -C "$repo" rev-parse main)"

  local state_file="$repo/.execplan/state.env"
  mkdir -p "$(dirname "$state_file")"
  cat > "$state_file" <<STATE
EXECPLAN_ID=forged-execplan
STATE=MERGED
FEATURE_BRANCH=$feature_branch
TARGET_BRANCH=main
VALIDATION_CMD=:
CHECKLIST_CHECKED_COUNT=0
LAST_CHECKLIST_CHECKED_COUNT=0
STAGNATION_CYCLES_COUNT=0
LAST_PROGRESS_EPOCH=2000000000
TOTAL_CYCLES_COUNT=0
LAST_STATE=MERGED
LAST_FEATURE_HEAD_SHA=$feature_tip_sha
MERGED_COMMIT_SHA=$fake_merged_sha
MERGED_FEATURE_TIP_SHA=$feature_tip_sha
MERGED_TARGET_BRANCH=main
MERGE_EVIDENCE_VERSION=v1
CLEANUP_DONE=0
STATE

  if "$ORCH_SCRIPT" \
    --repo-root "$repo" \
    --state-file "$state_file" \
    --feature-branch "$feature_branch" \
    --target-branch main \
    --validation-cmd ":" \
    --mark-feature-done \
    >/dev/null 2>&1; then
    fail "forged merged sha should be rejected"
  fi

  load_state "$state_file"
  assert_eq "$STATE" "BLOCKED" "forged merged sha should block completion"
  assert_eq "$LAST_ERROR" "merged_feature_tip_not_ancestor" "forged merged sha should fail merge evidence chain"
}

test_feature_done_triggers_cleanup() {
  log "test_feature_done_triggers_cleanup"
  local repo
  repo="$(create_repo t04-feature-done-cleanup)"
  local feature_branch="feature/feature-done"
  create_feature_commit "$repo" "$feature_branch" "feature-done"

  local state_file="$repo/.execplan/state.env"
  mkdir -p "$(dirname "$state_file")"

  "$ORCH_SCRIPT" \
    --repo-root "$repo" \
    --state-file "$state_file" \
    --feature-branch "$feature_branch" \
    --target-branch main \
    --validation-cmd ":" \
    --audit-result AUDIT_PASS \
    >/dev/null

  printf 'cleanup-me\n' > "$repo/.coverage.tmp"

  "$ORCH_SCRIPT" \
    --repo-root "$repo" \
    --state-file "$state_file" \
    --feature-branch "$feature_branch" \
    --target-branch main \
    --validation-cmd ":" \
    --mark-feature-done \
    >/dev/null

  load_state "$state_file"
  assert_eq "$STATE" "FEATURE_DONE" "state should become FEATURE_DONE"
  assert_eq "$EXIT_SIGNAL" "FEATURE_DONE" "exit signal should become FEATURE_DONE"
  assert_eq "$CLEANUP_DONE" "1" "cleanup should run on FEATURE_DONE"
  assert_file_missing "$repo/.coverage.tmp" "FEATURE_DONE cleanup should remove temp files"
}

test_cleanup_keeps_tracked_files() {
  log "test_cleanup_keeps_tracked_files"
  local repo
  repo="$(create_repo t05-cleanup-safety)"

  mkdir -p "$repo/.pytest_cache"
  printf 'tracked\n' > "$repo/.pytest_cache/keep.txt"
  git -C "$repo" add .pytest_cache/keep.txt
  git -C "$repo" commit -q -m "track cleanup sentinel"

  local feature_branch="feature/tracked-safety"
  create_feature_commit "$repo" "$feature_branch" "tracked-safety"

  local state_file="$repo/.execplan/state.env"
  mkdir -p "$(dirname "$state_file")"
  mkdir -p "$repo/tmp"
  printf 'untracked\n' > "$repo/tmp/throwaway.tmp"

  run_until_blocked_exit "$repo" "$state_file" "$feature_branch" || fail "stagnation exit should trigger in tracked-file cleanup test"

  load_state "$state_file"
  assert_eq "$STATE" "FEATURE_BLOCKED_EXIT" "cleanup safety test should end with FEATURE_BLOCKED_EXIT"
  assert_eq "$CLEANUP_DONE" "1" "cleanup should run on FEATURE_BLOCKED_EXIT"
  assert_file_exists "$repo/.pytest_cache/keep.txt" "cleanup must not remove tracked files"
  assert_file_missing "$repo/tmp/throwaway.tmp" "cleanup should remove untracked temp files"
}

main() {
  log "workspace: $TEST_ROOT"

  test_default_stagnation_exit
  test_audit_pass_forces_merge
  test_forged_merged_sha_rejected
  test_feature_done_triggers_cleanup
  test_cleanup_keeps_tracked_files

  log "PASS: all execplan e2e tests"
}

main "$@"
