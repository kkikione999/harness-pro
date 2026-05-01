# Step 5: Validate & Complete

## Validate

Run build and test based on the scope of changes:

```
build → test
```

Run lint checks if available (`./scripts/lint-deps`, `./scripts/lint-quality`).

If validation fails, fix and retry (up to 3 attempts). Still failing — escalate to the user.

## Complete

1. **Git commit**: Stage specific files (no `git add -A`), use conventional commit format
2. **Report**: Summarize what was done and which validations passed
