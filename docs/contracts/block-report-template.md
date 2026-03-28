# BLOCK_REPORT Template

Use JSON or Markdown. JSON is recommended for machine processing.

## JSON Template
```json
{
  "execplan_id": "EP-001",
  "signal": "FEATURE_BLOCKED_EXIT",
  "blocked_at": "2026-03-29T01:23:45Z",
  "checkpoint_id": "BLK-STAGNATION-95",
  "reason": "Checklist >=95% and no new checks in stagnation window",
  "evidence": {
    "feature_checklist_percent": 97,
    "checklist_checked_count": 39,
    "previous_checked_count": 39,
    "stagnation_cycles": 3,
    "minutes_without_progress": 140
  },
  "impact": "Feature cannot be safely completed in current cycle",
  "recommendation": [
    "Escalate owner for blocking item",
    "Split unresolved item into new ExecPlan",
    "Re-run orchestration after unblock"
  ],
  "attachments": [
    "logs/orchestrator/EP-001.jsonl"
  ]
}
```

## Required Fields
- `execplan_id`
- `signal`
- `blocked_at`
- `checkpoint_id` (卡点ID)
- `reason`
- `evidence`
- `impact`
- `recommendation`
