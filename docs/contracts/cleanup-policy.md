# Closeout Cleanup Policy

## Trigger
Cleanup MUST run after feature flow exits with either:
- `FEATURE_DONE`
- `FEATURE_BLOCKED_EXIT`

## Mandatory Scope
- temporary files (`*.tmp`, `*.temp`, `*~`)
- OS junk (`.DS_Store`)
- temporary test artifacts (`.pytest_cache/`, coverage temp files)
- orphan or stale worktree directories under `.worktrees/`

## Safety Boundary
- MUST NOT delete tracked files.
- MUST skip any path that is tracked or contains tracked content.
- Worktree removal should prefer clean worktrees; dirty worktrees should be reported and skipped unless explicitly forced.

## Skip Behavior
- `--skip-cleanup` is debug-only.
- Production flow MUST NOT rely on `--skip-cleanup`.
- Any use of `--skip-cleanup` should be logged as an explicit exception.

## Evidence
Cleanup should output a summary including:
- removed files count
- removed directories count
- removed worktrees count
- skipped tracked paths

## Logging
Cleanup actions MUST be written into `logs/orchestrator/*.jsonl`.
