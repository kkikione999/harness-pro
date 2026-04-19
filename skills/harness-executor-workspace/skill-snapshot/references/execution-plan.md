# Execution Plan Template

For medium/complex tasks, create an execution plan at `docs/exec-plans/{task-name}.md` using this template.

## Template

```markdown
# Execution Plan: {task-name}

## Objective
{What we're building/fixing — one clear sentence}

## Impact Scope
{Which packages/modules affected — list each with layer number}

## Steps
1. {Step 1}
2. {Step 2}
3. {Step 3}

## Validation
- [ ] Build passes
- [ ] lint-deps passes
- [ ] Tests pass
- [ ] verify passes (if applicable)

## Rollback Plan
{How to undo if things go wrong — branch name, revert strategy}

## Checkpoint After
{When to save state for recovery — which phase boundary}
```

## Approval Process

1. Write the plan file
2. Present summary to human: objective, scope, risk level
3. **Wait for explicit approval** — do not proceed until human confirms
4. If human requests changes → update plan, re-present
5. If human rejects → exit with code 3

## Plan Quality Checklist

- [ ] Objective is unambiguous (could another developer understand it?)
- [ ] Impact scope lists every affected package with layer number
- [ ] Steps are ordered and each is independently verifiable
- [ ] Validation checklist matches the task's impact scope
- [ ] Rollback plan is concrete (not "revert the changes")
