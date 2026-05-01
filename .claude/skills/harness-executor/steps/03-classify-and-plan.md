# Step 3: Classify & Plan

## Classify Complexity

Ask yourself: **Can I describe this task in one sentence (without "and")?**

| Complexity | Criteria | Action |
|------------|----------|--------|
| **Simple** | One file, typo fix, < 5 lines | Skip planning, go to Step 4 |
| **Medium** | Multi-file, follows existing patterns | Spawn planner sub-agent for brief plan |
| **Complex** | Refactor, new module, architecture decision | Spawn planner sub-agent for detailed plan |

**Simple task checklist** (ALL must be YES):
- Only 1 file changed?
- Changes < 5 lines?
- No new imports or dependencies?
- No architecture decisions?
- No test changes (except updating expectations)?

Any NO → at least **Medium**.

## Plan (Medium/Complex only)

Spawn a **planner sub-agent** (loading `harness-planner` skill). Pass in the spawn prompt:
- Task description (user's original request)
- Project root directory
- Architecture summary from Step 2
- Complexity level (Medium or Complex)

The planner sub-agent writes the plan and returns the plan file path. Present the plan summary to the user for visibility. No approval gate — proceed to Step 4.
