# P0 Lint Guide

This guide explains how to discover and run lint checks for any project. Read this file when you need to run lint at milestone boundaries or during verification.

## Why lint at milestones

The worker just wrote code. Before spawning an independent reviewer, run computational sensors to catch the easy stuff — secrets, oversized files, style violations. This saves the reviewer from wasting time on mechanical issues, and catches problems while the code is fresh.

## How to discover project lint commands

### From CLAUDE.md

Read the project's `CLAUDE.md` and look for the Development section. It should contain command strings like:

```
# Test
xcodebuild test -scheme AudioStrobe -destination '...'
# Lint
swiftlint lint
```

These are command strings only — not rules. The rules live in the project's own tooling configuration.

### Auto-detection (fallback)

If CLAUDE.md doesn't specify lint commands, check for common patterns:

| Project file | Lint command | Test command |
|---|---|---|
| `package.json` | `npm run lint` | `npm test` |
| `Makefile` | `make lint` | `make test` |
| `*.xcodeproj` | N/A (Xcode has no built-in lint) | `xcodebuild test -scheme {name}` |
| `pyproject.toml` | `ruff check .` | `pytest` |
| `go.mod` | `golangci-lint run` | `go test ./...` |

If you can't find any lint tooling, that's OK — just run the P0 universal checks (they don't depend on project tooling).

## What to run at milestone boundaries

### Always (universal)

```bash
bash .claude/skills/harness-pro-execute-task/scripts/p0-checks.sh
```

This checks: hardcoded secrets, file size limits, TODO/FIXME residuals.

### If available (project-specific)

Run the project's own lint command discovered above.

## How to interpret results

| Level | Source | Action |
|---|---|---|
| CRITICAL | P0 checks (secret, file size) | Must fix before reviewer |
| ERROR | Project lint | Fix before reviewer |
| WARNING | Project lint or P0 TODO check | Log, continue |

## How to fix

P0 violations come with a "Fix:" line in the output — follow it. For project lint errors, read the error message, understand the rule being violated, and fix the code to comply. Do not suppress the rule.
