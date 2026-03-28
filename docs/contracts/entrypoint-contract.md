# Entrypoint Contract

## Purpose
Define the only supported start path for ExecPlan orchestration.

## Unique Entrypoint
The only valid entrypoint is:
1. owner updates the feature document
2. owner starts the main skill/orchestrator using that feature document as input

No alternate hidden entrypoint is allowed for completion bookkeeping.

## Required Inputs
The entrypoint must provide at least:
- feature identifier / `EXECPLAN_ID`
- `FEATURE_BRANCH`
- `TARGET_BRANCH`
- audit/checklist inputs required by orchestration
- state file path (`--state-file`)

## Canonical Runtime Artifacts
- state file: user-defined `--state-file` path
- orchestrator log: `logs/orchestrator/<execplan_id>.jsonl`
- blocked report (when triggered): `logs/orchestrator/block-reports/<execplan_id>-<timestamp>.{json|md}`

## State Machine Baseline
Entry flow must respect:
- `IN_DEV -> AUDIT_PENDING|AUDIT_PASS`
- `AUDIT_PASS -> MERGE_REQUIRED -> MERGED`
- only verified merge evidence can unlock `FEATURE_DONE`

## Exit Signal Semantics
- `FEATURE_DONE`: requires validated merge evidence chain
- `FEATURE_BLOCKED_EXIT`: emitted by stagnation rules with `BLOCK_REPORT`
- both exits MUST trigger cleanup (unless explicit debug-only skip)

## Skill Alignment
`.codex` and `.claude` main skills must both reference this entrypoint model and the same bottom-line rules:
- exit contract
- mandatory merge chain + evidence
- mandatory cleanup
