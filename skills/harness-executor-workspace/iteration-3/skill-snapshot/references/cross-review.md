# Cross-Review Process

After mechanical validation passes (Step 6), medium/complex tasks get reviewed by a **different model** than the one that wrote the code.

## Why Different Models

Same-model review suffers from "blind spot overlap" — the reviewer tends to miss the same issues the writer introduced. Using a model with different architecture and training data reduces this overlap significantly.

## Review Delegation

```python
Agent(
    description="Review: {task-name}",
    model="{different from coding model}",
    prompt="""Review these changes for:
1. Logic correctness and edge cases
2. Consistency with architecture in AGENTS.md
3. Naming clarity and code readability
4. Performance implications

Changes: {diff}
Task context: {task_description}
Project docs: docs/ARCHITECTURE.md

Report: PASS (no issues) or ISSUES (list each with severity: CRITICAL/HIGH/MEDIUM)"""
)
```

## Review Outcomes

| Result | Action |
|--------|--------|
| PASS | Proceed to Step 8 (Complete) |
| MEDIUM issues | Note for future reference, proceed to Step 8 |
| HIGH issues | Fix via sub-agent, re-validate affected pipeline steps |
| CRITICAL issues | Fix via sub-agent, run full validation pipeline |

If fixes are needed, the review-fix-revalidate cycle also has a context budget: max 2 rounds before escalating to human.

## When to Skip Cross-Review

- **Simple tasks** — direct execution, no delegation occurred
- **Changes < 20 lines** with no logic change (formatting, renames)
- **Auto-generated or boilerplate code** — templates, scaffolding
- **Test-only changes** — new tests, test fixes

## Review Output as Memory

Review findings (especially recurring MEDIUM issues) should be recorded to `harness/trace/`. If a pattern appears 3+ times across reviews, it becomes a candidate for a new `lint-quality` rule — converting "soft knowledge" into a "hard rule" in the validation pipeline.
