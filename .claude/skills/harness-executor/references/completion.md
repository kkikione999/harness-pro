# Completion: Git Operations

After all validations and review pass, commit the changes:

```bash
# 1. Stage changed files (be specific, not git add -A)
git add {specific-files}

# 2. Commit with conventional format
git commit -m "<type>: <description>"

# 3. For worktree tasks: push and optionally create PR
git push -u origin {branch-name}
# Optionally: gh pr create --title "..." --body "..."
```

## Commit Message Format

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`, `ci`

## Branch Strategy

| Complexity | Branch Strategy |
|-----------|----------------|
| Simple | Direct commit on current branch |
| Medium | Feature branch, commit, optionally PR |
| Complex | Worktree branch, full PR with review notes |
