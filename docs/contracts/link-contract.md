# Link Contract (Docs <-> Scripts <-> Skills)

## Purpose
Define canonical linkage between policy documents, executable scripts, and skill instructions.

## Entrypoint Contract
- canonical entrypoint: `docs/contracts/entrypoint-contract.md`
- unique entry rule: owner updates feature document first, then starts main skill/orchestrator

## Script Mapping
- `scripts/exec-plan-orchestrator.sh`
  - enforces lifecycle transitions
  - enforces `AUDIT_PASS -> MERGE_REQUIRED`
  - enforces completion gate with merge evidence chain
  - evaluates checklist stagnation and global no-progress stagnation
  - emits `FEATURE_BLOCKED_EXIT`
  - writes audit log to `logs/orchestrator/*.jsonl`

- `scripts/merge-verify-writeback.sh`
  - executes `sync + rebase/merge + revalidate + merge`
  - writes merge evidence fields back to state:
    - `MERGED_COMMIT_SHA`
    - `MERGED_FEATURE_TIP_SHA`
    - `MERGED_TARGET_BRANCH`
    - `MERGE_EVIDENCE_VERSION`

- `scripts/feature-closeout-cleanup.sh`
  - runs cleanup after exit signals
  - removes junk/temp/untracked artifacts safely
  - removes safe worktrees without deleting tracked files

## Skill Mapping
- `.codex/skills/harness-pro-main/SKILL.md`
- `.claude/skills/harness-pro-main/SKILL.md`

Both main skills MUST describe the same three bottom lines:
- exit rules (`FEATURE_DONE` / `FEATURE_BLOCKED_EXIT`)
- mandatory merge chain + merge evidence gate
- mandatory closeout cleanup without deleting tracked files

## Contract Dependency
- lifecycle rules: `execplan-lifecycle.md`
- exit semantics: `exit-signal-contract.md`
- cleanup safety: `cleanup-policy.md`
- blocked report output: `block-report-template.md`
- unique entrypoint: `entrypoint-contract.md`

## Compliance
Any implementation or skill instruction that violates these contracts is non-compliant and must not be used to mark ExecPlan completion.
