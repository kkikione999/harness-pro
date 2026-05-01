# Execution Plan Template

For medium/complex tasks, create an execution plan at `docs/exec-plans/{task-name}.md`.

## Template

```markdown
# Execution Plan: {task-name}

## Objective
{What we're building/fixing — one clear sentence, ≤50 chars}

## Scope
### DO
- {what this task covers}

### DON'T
- {what this task explicitly excludes}

## Done-when
### Acceptance Criteria
- Given {user context}, When {user action}, Then {observable outcome}

### Technical Checks
- [ ] {machine-checkable condition 1}
- [ ] {machine-checkable condition 2}

## Phases

### Phase 1: {name} — Layer {N}
- {specific file change or creation}
- {specific file change or creation}

### Phase 2: {name} — Layer {N}
- {specific file change or creation}

### Phase N: Validate
- Run validation pipeline: build → lint → test
```

## Approval Process

1. Write the plan file
2. Present summary to human: objective, scope, risk level
3. **Wait for explicit approval** — do not proceed until human confirms
4. If human requests changes → update plan, re-present
5. If human rejects → exit with code 3
