#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(pwd)"
STATE_FILE=""
FEATURE_BRANCH=""
TARGET_BRANCH="main"
VALIDATION_CMD=":"
LOG_FILE=""
MERGE_STRATEGY="rebase-first"
MERGE_EVIDENCE_VERSION="v1"

usage() {
  cat <<USAGE
Usage: $0 --state-file <file> [--repo-root <dir>] [--feature-branch <name>] [--target-branch <name>] [--validation-cmd <cmd>] [--log-file <file>]
USAGE
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

log_event() {
  local event="$1"
  local detail="${2:-}"
  if [[ -z "${LOG_FILE}" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$LOG_FILE")"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf '{"ts":"%s","event":"%s","detail":"%s","state_file":"%s","feature_branch":"%s","target_branch":"%s"}\n' \
    "$ts" "$(json_escape "$event")" "$(json_escape "$detail")" "$(json_escape "$STATE_FILE")" "$(json_escape "$FEATURE_BRANCH")" "$(json_escape "$TARGET_BRANCH")" \
    >> "$LOG_FILE"
}

upsert_kv() {
  local file="$1"
  local key="$2"
  local value="$3"
  local tmp
  tmp="$(mktemp)"

  if [[ -f "$file" ]]; then
    awk -v k="$key" -v v="$value" '
      BEGIN { found=0 }
      $0 ~ "^"k"=" { print k"="v; found=1; next }
      { print }
      END { if (!found) print k"="v }
    ' "$file" > "$tmp"
  else
    printf '%s=%s\n' "$key" "$value" > "$tmp"
  fi

  mv "$tmp" "$file"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --state-file)
      STATE_FILE="$2"
      shift 2
      ;;
    --feature-branch)
      FEATURE_BRANCH="$2"
      shift 2
      ;;
    --target-branch)
      TARGET_BRANCH="$2"
      shift 2
      ;;
    --validation-cmd)
      VALIDATION_CMD="$2"
      shift 2
      ;;
    --log-file)
      LOG_FILE="$2"
      shift 2
      ;;
    --merge-strategy)
      MERGE_STRATEGY="$2"
      shift 2
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

if [[ -f "$STATE_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$STATE_FILE"
fi

MERGE_EVIDENCE_VERSION="${MERGE_EVIDENCE_VERSION:-v1}"

FEATURE_BRANCH="${FEATURE_BRANCH:-${FEATURE_BRANCH_NAME:-}}"
if [[ -z "$FEATURE_BRANCH" ]]; then
  echo "feature branch is required (argument or state file FEATURE_BRANCH)" >&2
  exit 1
fi

if [[ -z "$LOG_FILE" ]]; then
  local_execplan="${EXECPLAN_ID:-default}"
  LOG_FILE="$REPO_ROOT/logs/orchestrator/${local_execplan}.jsonl"
fi

if [[ -n "$(git -C "$REPO_ROOT" status --porcelain --untracked-files=no)" ]]; then
  echo "Repository has tracked pending changes; merge flow requires clean tracked state." >&2
  log_event "merge_failed" "tracked pending changes"
  upsert_kv "$STATE_FILE" "STATE" "BLOCKED"
  upsert_kv "$STATE_FILE" "LAST_ERROR" "tracked_pending_changes"
  exit 1
fi

start_branch="$(git -C "$REPO_ROOT" branch --show-current)"

if git -C "$REPO_ROOT" remote get-url origin >/dev/null 2>&1; then
  log_event "sync_start" "git fetch origin"
  git -C "$REPO_ROOT" fetch origin --prune
  log_event "sync_done" "fetch completed"
else
  log_event "sync_skipped" "origin remote not configured"
fi

if ! git -C "$REPO_ROOT" rev-parse --verify "$TARGET_BRANCH" >/dev/null 2>&1; then
  echo "Target branch not found: $TARGET_BRANCH" >&2
  log_event "merge_failed" "target branch not found"
  upsert_kv "$STATE_FILE" "STATE" "BLOCKED"
  upsert_kv "$STATE_FILE" "LAST_ERROR" "target_branch_not_found"
  exit 1
fi

if ! git -C "$REPO_ROOT" rev-parse --verify "$FEATURE_BRANCH" >/dev/null 2>&1; then
  echo "Feature branch not found: $FEATURE_BRANCH" >&2
  log_event "merge_failed" "feature branch not found"
  upsert_kv "$STATE_FILE" "STATE" "BLOCKED"
  upsert_kv "$STATE_FILE" "LAST_ERROR" "feature_branch_not_found"
  exit 1
fi

log_event "merge_flow_start" "checkout feature branch"
git -C "$REPO_ROOT" checkout "$FEATURE_BRANCH" >/dev/null

if [[ "$MERGE_STRATEGY" == "rebase-first" ]]; then
  log_event "rebase_start" "rebase feature onto target"
  if git -C "$REPO_ROOT" rebase "$TARGET_BRANCH"; then
    log_event "rebase_done" "rebase successful"
  else
    log_event "rebase_failed" "fallback to merge target into feature"
    git -C "$REPO_ROOT" rebase --abort >/dev/null 2>&1 || true
    git -C "$REPO_ROOT" merge --no-edit "$TARGET_BRANCH"
    log_event "merge_target_into_feature_done" "fallback merge completed"
  fi
fi

log_event "revalidate_start" "$VALIDATION_CMD"
(
  cd "$REPO_ROOT"
  eval "$VALIDATION_CMD"
)
log_event "revalidate_done" "validation passed"

merged_feature_tip_sha="$(git -C "$REPO_ROOT" rev-parse "$FEATURE_BRANCH")"
if [[ -z "$merged_feature_tip_sha" ]]; then
  log_event "merge_failed" "empty merged feature tip sha"
  upsert_kv "$STATE_FILE" "STATE" "BLOCKED"
  upsert_kv "$STATE_FILE" "LAST_ERROR" "empty_merged_feature_tip_sha"
  exit 1
fi

git -C "$REPO_ROOT" checkout "$TARGET_BRANCH" >/dev/null
log_event "final_merge_start" "merge feature into target"
git -C "$REPO_ROOT" merge --no-ff --no-edit "$FEATURE_BRANCH"
log_event "final_merge_done" "feature merged into target"

log_event "post_merge_validate_start" "$VALIDATION_CMD"
(
  cd "$REPO_ROOT"
  eval "$VALIDATION_CMD"
)
log_event "post_merge_validate_done" "validation passed"

merged_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
if [[ -z "$merged_sha" ]]; then
  log_event "merge_failed" "empty merged sha"
  upsert_kv "$STATE_FILE" "STATE" "BLOCKED"
  upsert_kv "$STATE_FILE" "LAST_ERROR" "empty_merged_sha"
  exit 1
fi

if ! git -C "$REPO_ROOT" merge-base --is-ancestor "$merged_feature_tip_sha" "$merged_sha"; then
  log_event "merge_failed" "feature tip is not ancestor of merged commit"
  upsert_kv "$STATE_FILE" "STATE" "BLOCKED"
  upsert_kv "$STATE_FILE" "LAST_ERROR" "invalid_merge_ancestry"
  exit 1
fi

git -C "$REPO_ROOT" checkout "$start_branch" >/dev/null

upsert_kv "$STATE_FILE" "STATE" "MERGED"
upsert_kv "$STATE_FILE" "MERGED_COMMIT_SHA" "$merged_sha"
upsert_kv "$STATE_FILE" "MERGED_FEATURE_TIP_SHA" "$merged_feature_tip_sha"
upsert_kv "$STATE_FILE" "MERGED_TARGET_BRANCH" "$TARGET_BRANCH"
upsert_kv "$STATE_FILE" "MERGE_EVIDENCE_VERSION" "$MERGE_EVIDENCE_VERSION"
upsert_kv "$STATE_FILE" "MERGE_COMPLETED_AT" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
upsert_kv "$STATE_FILE" "LAST_ERROR" ""

log_event "merge_flow_done" "merged_commit_sha=$merged_sha merged_feature_tip_sha=$merged_feature_tip_sha target_branch=$TARGET_BRANCH evidence_version=$MERGE_EVIDENCE_VERSION"
printf '%s\n' "$merged_sha"
