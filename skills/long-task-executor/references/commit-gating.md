# Commit Gating

Auto-committing is a high-leverage action. A correct auto-commit saves the user 30 seconds; an incorrect one can leak secrets, lose work, or pollute history. The asymmetry justifies a conservative default: if any gate fails, **ask the user instead of acting**.

## The four gates

### Gate 1 — Git available

```bash
git rev-parse --is-inside-work-tree
```

Pass: returns `true` and exit code 0. Fail: anything else. If git isn't available, there's nothing to commit; report completion and stop.

### Gate 2 — Tree clean before & after (relative to this skill's changes)

Before any worker runs (Step 1 or Step 4 entry), capture the dirty set:

```bash
git status --porcelain > /tmp/long-task-pre.txt
```

After all workers and the e2e-runner are done, compare:

```bash
git status --porcelain > /tmp/long-task-post.txt
```

The acceptable post-state is: pre-state files (still dirty, still untracked) + the files this skill explicitly changed. If there are extra dirty/untracked files that weren't in the pre-state and weren't expected, **don't commit** — they might be the user's in-progress work, an accidental write by a sub-agent, or a generated file the project doesn't want tracked.

### Gate 3 — Tests pass

The e2e-runner's report from Step 6 must show test command exit code 0 (or however the project signals success). If the e2e-runner reported test failures and they were not subsequently fixed in another review-loop round, **don't commit**.

If no test command exists for the project, you cannot pass Gate 3 — surface that to the user: "I don't see a test command. I'm not going to auto-commit without one. Should I commit anyway, or do you want me to add a test first?"

### Gate 4 — No secrets in the diff

Run a pattern scan over `git diff --staged` (or `git diff` if not staged yet). Patterns to flag:

- `(?i)api[_-]?key\s*[:=]\s*["']?[a-z0-9_\-]{16,}`
- `(?i)secret[_-]?key\s*[:=]\s*["']?[a-z0-9_\-]{16,}`
- `(?i)password\s*[:=]\s*["']?\S{8,}`
- `-----BEGIN (RSA|EC|OPENSSH|PGP) PRIVATE KEY-----`
- `(?i)bearer\s+[a-z0-9_\-\.]{20,}`
- `AKIA[0-9A-Z]{16}` (AWS access key id)
- `xox[baprs]-[0-9a-zA-Z\-]{10,}` (Slack tokens)
- `gh[pousr]_[A-Za-z0-9_]{36,}` (GitHub tokens)

Any match → **stop**. Show the user the matched line and ask. False positives are fine; the user can confirm in 5 seconds.

## When all gates pass — the commit message

Use conventional commits style. The subject describes what changed in user terms; the body (optional, only if non-obvious) explains why.

```
<type>(<scope>): <imperative summary>

<optional body — why, not what>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`. Scope is the area of the codebase (e.g. `auth`, `api`, `dashboard`).

Examples:

```
feat(auth): add rate-limit middleware to login endpoint

Pre-empts the brute-force attempts noted in the security review;
caps a single IP at 5 attempts/minute.
```

```
fix(dashboard): handle empty state without throwing

The metrics call returned [] for new accounts, which crashed
the chart renderer. Now shows the empty-state placeholder.
```

```
refactor(billing): extract retry helper from invoice service
```

## When a gate fails — the escalation message

Don't commit. Don't try to clean up silently. Give the user a structured choice:

> "I'm ready to commit but stopped at gate [N]:
>
> **Gate 4 — secrets**: the diff in `src/config/loader.ts:88` contains a string matching the AWS-key pattern: `AKIAIOSFODNN7EXAMPLE`. Looks like an example key, but I'd like you to confirm.
>
> Options:
> 1. **Yes, commit anyway** — confirmed it's not a real secret
> 2. **No, let me edit it first** — I'll wait
> 3. **Show me the full context** — I'll print the surrounding lines"

Wait. Don't act until the user picks.

## What about `--no-verify`?

Don't. If a pre-commit hook fails, that's the project telling you something. Investigate, fix, re-stage, commit. Bypassing hooks is a destructive action that deserves an explicit user request, not a unilateral decision.
