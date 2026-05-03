# Step 1 — Read Context

Goal: build a working understanding of the project and the user's request before you say anything to the user.

## Read these in parallel

1. **`CLAUDE.md`** at the project root. If absent, walk upward up to the user home directory and read the first one you find. If still none, note "no CLAUDE.md found" and continue — don't fabricate one.
2. **The conversation history** — what has the user already said? What context, files, or decisions have come up earlier?
3. **`README.md`** if it exists — useful for naming conventions and high-level structure.
4. **A `git status` and `git log -5 --oneline`** if the project is a git repo — shows current working state.

## Identify

- **Project root** — usually the cwd, but verify by looking for marker files (`.git`, `package.json`, `go.mod`, `pyproject.toml`, etc.)
- **Tech stack** — language, framework, test runner, build tool
- **Existing test command** — extract from `package.json`, `Makefile`, or CLAUDE.md so the teammate has it later
- **Whether git is available** — needed for Step 7's commit gate

## Output (internal, not yet shown to user)

Hold these in working memory for Step 2. Do not dump the raw file contents into your reply — the user already knows what's in their own CLAUDE.md.

## Skip rules

- If the project has no CLAUDE.md and the user explicitly asked you to "just do X quickly", you may shortcut Step 2 to a one-line restatement instead of a full restate. The approval gate still applies.
- Never skip reading the conversation history. The most common cause of mismatched expectations is forgetting something the user said three turns ago.
