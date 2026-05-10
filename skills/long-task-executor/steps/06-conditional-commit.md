# Step 7 — Conditional Commit

Goal: commit to git only when it is genuinely safe to do so. Default behavior when in doubt: don't commit, ask the user.

## The four gates

All four must pass for an automatic commit. If any fails, surface the situation to the user and let them decide.

| Gate | Check | How |
|------|-------|-----|
| 1. Git available | The project is a git repo and we can run git | `git rev-parse --is-inside-work-tree` returns `true` |
| 2. Tree clean before & after the orchestrated changes | No unrelated dirty files or untracked junk | `git status --porcelain` shows only files this skill changed |
| 3. Tests pass | The e2e-runner reported tests PASS in Step 6 | Already in your context |
| 4. No secrets in the diff | No API keys, passwords, tokens, private keys | Pattern scan over the diff (see `references/commit-gating.md`) |

## How to commit (when all gates pass)

Use a conventional-commits style message. The body should reference what the user originally asked for (paraphrased), not what each phase did:

```bash
git add <only the files this skill changed>
git commit -m "$(cat <<'EOF'
feat(area): short summary

[1-2 line body explaining the why, in user terms]
EOF
)"
```

Then run `git status` and report the new commit SHA to the user.

## When a gate fails

Don't commit. Don't try to "clean up" the tree silently. Instead, write a short report:

> "I'm ready to commit but I'm not going to automatically because:
> - Gate 2 (clean tree): there are 3 untracked files I didn't create — `[list]`. They might be your in-progress work.
>
> What would you like to do?
> - **Commit only my changes**: I can stage exactly `[list]` and commit
> - **You handle staging**: I'll leave it to you
> - **Investigate first**: I can show you what's in those files"

The user picks; you act.

## Specific failure modes

- **Tree was dirty before we started** — tell the user; offer to commit only the files this skill touched
- **Tests pass locally but no test command was found** — escalate; "tests pass" can't be claimed without evidence
- **Diff contains a string that looks like a secret** — STOP. Show the user the line. Even false positives are worth a 5-second confirmation.
- **Pre-commit hook fails** — fix the underlying issue, do **not** bypass with `--no-verify`. If you can't fix it, escalate.

## Why this is gated this way

Auto-committing is high-leverage. A good auto-commit saves the user a 30-second action; a bad auto-commit can require 30 minutes of `git reflog` archaeology, or worse, can leak a secret into history. The asymmetry justifies being conservative: the worst case for "asked unnecessarily" is mild user annoyance; the worst case for "committed too eagerly" is real harm.

## Skip rules

If the user said "no commits" or "I'll commit myself" anywhere in the conversation, **don't commit**. If the user said "commit and push", do the commit but still apply the four gates — the push is even higher-leverage and gets its own confirmation by default unless the user pre-authorized it for this exact change.
