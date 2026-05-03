# Review Loop — How to read findings and craft fix prompts

The review loop's success or failure depends on the quality of the spawn prompts you give the fix-worker. Reviewer findings are not always actionable as written — your job is to translate them.

## Reading reviewer output

A typical reviewer return looks like:

```
GRADE: HIGH
ISSUES:
1. [HIGH] src/api/users.ts:42 — handler swallows the database error and returns 200
2. [MEDIUM] src/api/users.ts:60 — variable name `tmp` is unclear
3. [HIGH] src/api/users.test.ts: missing test for the empty-payload case
```

Three findings, two HIGH, one MEDIUM. The grade is HIGH (worst-of). Your fix-worker prompt must address the HIGHs; the MEDIUM you can decide to fix or note-and-skip.

## Translating findings into a fix prompt

A bad prompt:

> Fix the issues the reviewer found.

A good prompt:

> The reviewer flagged these issues. Fix exactly these, no other changes:
>
> 1. **src/api/users.ts:42** — the catch block currently does `return res.status(200).send({})`. It should propagate the error (use `next(err)` or return 500 with a generic error envelope; check the existing error pattern in `src/api/orders.ts` for the convention).
> 2. **src/api/users.test.ts** — add one test case: `POST /users` with body `{}` should return 400 with `{ error: "missing required fields" }`.
>
> Don't touch the `tmp` variable on line 60 (separately noted as MEDIUM, we're skipping it this round).
>
> When done, return: files changed + diff summary + confirmation that issues 1 and 2 are addressed.

The good prompt does three things the bad prompt doesn't:
- Quotes the file:line so the worker doesn't have to re-find it
- Suggests the fix direction (catches the case where the worker would otherwise re-implement the same broken logic)
- Calls out what NOT to fix (prevents scope creep into the MEDIUM)

## Why the loop has no cap

A fixed cap (say, 3 iterations) creates a perverse incentive: the system learns that "if iteration 3 looks okay-ish, ship it." The reviewer's standards quietly relax under cap pressure.

Better:
- Loop indefinitely on PASS
- Detect when you're not making progress (same issue flagged 3+ times, or diff is oscillating) and **escalate to the user**, don't auto-stop

The escalation isn't a failure mode — it's the correct behavior when the system genuinely needs human input.

## Detecting "not making progress"

After each loop iteration, ask yourself:

- Is the new reviewer output strictly smaller than the previous one (issues being resolved)?
- Are any of the same issues from round N still flagged in round N+1 with the same description?
- Has the worker's diff been touching the same lines repeatedly?

If you'd answer no/yes/yes: you're spinning. Escalate.

Escalation template:

> "I've gone through 3 review rounds and the reviewer keeps flagging [issue]. Here's what each round of the worker tried:
>
> Round 1: [approach + result]
> Round 2: [approach + result]
> Round 3: [approach + result]
>
> I think [hypothesis about why this is stuck]. Options:
> 1. Drop the requirement that's causing the conflict
> 2. Refactor the surrounding code to remove the conflict
> 3. Mark the issue as 'won't fix' and proceed
>
> Which would you like?"

## Why not have the reviewer fix things itself

Cleanly separating "criticize" from "fix" makes both jobs easier:
- The reviewer can be ruthless without worrying about implementation difficulty
- The worker stays focused on code, not arguing with critique
- You (the orchestrator) own the call about what's worth fixing

If the reviewer also fixed things, it would gradually develop blind spots toward issues that are hard to fix, because acknowledging them would create work. The split prevents that.
