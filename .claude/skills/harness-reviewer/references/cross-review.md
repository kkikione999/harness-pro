# Cross-Review Process

After mechanical validation passes, medium/complex tasks get reviewed.

## Review Dimensions

Evaluate changes across these five dimensions:

1. **Logic Correctness** — Does it do what the task requires? Edge cases handled?
2. **Architecture Consistency** — Follows layer rules? Dependencies correct?
3. **Naming and Readability** — Clear without explanation? Comments unnecessary?
4. **Performance Impact** — N+1 queries? Unnecessary allocations?
5. **Over-Engineering** — Unnecessary abstractions? Scope creep?

## Review Outcomes

| Result | Action |
|--------|--------|
| PASS | Proceed to Complete |
| MEDIUM | Note for future, proceed |
| HIGH | Fix via sub-agent, re-validate affected steps |
| CRITICAL | Fix via sub-agent, full re-validation |

If fixes are needed, max 2 review-fix rounds before escalating to human.
