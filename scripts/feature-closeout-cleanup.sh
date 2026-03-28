#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(pwd)"
WORKTREE_PREFIX=".worktrees"
DRY_RUN=0
LOG_FILE=""

usage() {
  cat <<USAGE
Usage: $0 [--repo-root <dir>] [--worktree-prefix <dir>] [--log-file <file>] [--dry-run]
USAGE
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

log_event() {
  local event="$1"
  local detail="${2:-}"
  if [[ -z "$LOG_FILE" ]]; then
    return 0
  fi
  mkdir -p "$(dirname "$LOG_FILE")"
  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf '{"ts":"%s","event":"%s","detail":"%s"}\n' "$ts" "$(json_escape "$event")" "$(json_escape "$detail")" >> "$LOG_FILE"
}

is_tracked_path() {
  local rel="$1"
  if git -C "$REPO_ROOT" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1; then
    return 0
  fi
  if [[ -d "$REPO_ROOT/$rel" ]] && [[ -n "$(git -C "$REPO_ROOT" ls-files -- "$rel")" ]]; then
    return 0
  fi
  return 1
}

remove_file_if_untracked() {
  local abs="$1"
  local rel="${abs#$REPO_ROOT/}"
  if is_tracked_path "$rel"; then
    skipped_tracked=$((skipped_tracked + 1))
    log_event "cleanup_skip_tracked" "$rel"
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_event "cleanup_dryrun_file" "$rel"
    return
  fi

  rm -f "$abs"
  removed_files=$((removed_files + 1))
  log_event "cleanup_remove_file" "$rel"
}

remove_dir_if_untracked() {
  local abs="$1"
  local rel="${abs#$REPO_ROOT/}"
  if is_tracked_path "$rel"; then
    skipped_tracked=$((skipped_tracked + 1))
    log_event "cleanup_skip_tracked" "$rel"
    return
  fi

  if [[ "$DRY_RUN" -eq 1 ]]; then
    log_event "cleanup_dryrun_dir" "$rel"
    return
  fi

  rm -rf "$abs"
  removed_dirs=$((removed_dirs + 1))
  log_event "cleanup_remove_dir" "$rel"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      REPO_ROOT="$2"
      shift 2
      ;;
    --worktree-prefix)
      WORKTREE_PREFIX="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --log-file)
      LOG_FILE="$2"
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

if [[ ! -d "$REPO_ROOT/.git" ]]; then
  echo "Not a git repository: $REPO_ROOT" >&2
  exit 1
fi

REPO_ROOT="$(cd "$REPO_ROOT" && pwd -P)"

removed_files=0
removed_dirs=0
removed_worktrees=0
skipped_tracked=0

log_event "cleanup_start" "repo=$REPO_ROOT dry_run=$DRY_RUN"

while IFS= read -r abs; do
  [[ -z "$abs" ]] && continue
  remove_file_if_untracked "$abs"
done < <(find "$REPO_ROOT" -type f \( -name '.DS_Store' -o -name '*.tmp' -o -name '*.temp' -o -name '*~' -o -name '.coverage.tmp' -o -name '.coverage.*.tmp' \) 2>/dev/null)

for d in ".pytest_cache" ".mypy_cache" ".ruff_cache" ".tmp" "tmp"; do
  if [[ -d "$REPO_ROOT/$d" ]]; then
    remove_dir_if_untracked "$REPO_ROOT/$d"
  fi
done

if git -C "$REPO_ROOT" worktree list --porcelain >/dev/null 2>&1; then
  while IFS= read -r line; do
    [[ "$line" != worktree* ]] && continue
    wt_path="${line#worktree }"

    if [[ "$wt_path" == "$REPO_ROOT" ]]; then
      continue
    fi

    if [[ "$wt_path" != "$REPO_ROOT/$WORKTREE_PREFIX"* ]]; then
      continue
    fi

    if [[ ! -d "$wt_path" ]]; then
      continue
    fi

    if [[ -n "$(git -C "$wt_path" status --porcelain 2>/dev/null || true)" ]]; then
      log_event "cleanup_skip_dirty_worktree" "$wt_path"
      continue
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_event "cleanup_dryrun_worktree" "$wt_path"
      continue
    fi

    git -C "$REPO_ROOT" worktree remove "$wt_path" >/dev/null
    removed_worktrees=$((removed_worktrees + 1))
    log_event "cleanup_remove_worktree" "$wt_path"
  done < <(git -C "$REPO_ROOT" worktree list --porcelain)
  if [[ "$DRY_RUN" -eq 0 ]]; then
    git -C "$REPO_ROOT" worktree prune --expire now >/dev/null
    log_event "cleanup_worktree_prune" "pruned stale worktree metadata"
  fi
fi

if [[ -d "$REPO_ROOT/$WORKTREE_PREFIX" ]]; then
  while IFS= read -r orphan_dir; do
    [[ -z "$orphan_dir" ]] && continue
    if [[ "$DRY_RUN" -eq 1 ]]; then
      log_event "cleanup_dryrun_orphan_dir" "$orphan_dir"
      continue
    fi

    rel="${orphan_dir#$REPO_ROOT/}"
    if is_tracked_path "$rel"; then
      skipped_tracked=$((skipped_tracked + 1))
      log_event "cleanup_skip_tracked" "$rel"
      continue
    fi

    rm -rf "$orphan_dir"
    removed_dirs=$((removed_dirs + 1))
    log_event "cleanup_remove_orphan_dir" "$rel"
  done < <(find "$REPO_ROOT/$WORKTREE_PREFIX" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
fi

log_event "cleanup_done" "removed_files=$removed_files removed_dirs=$removed_dirs removed_worktrees=$removed_worktrees skipped_tracked=$skipped_tracked"

printf 'removed_files=%s\n' "$removed_files"
printf 'removed_dirs=%s\n' "$removed_dirs"
printf 'removed_worktrees=%s\n' "$removed_worktrees"
printf 'skipped_tracked=%s\n' "$skipped_tracked"
