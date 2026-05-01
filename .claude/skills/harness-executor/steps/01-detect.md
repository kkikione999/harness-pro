# Step 1: Detect

Check if `AGENTS.md` exists in the project root.

**If AGENTS.md exists:**
Proceed to Step 2.

**If AGENTS.md does not exist:**
You are not in a harness-managed project. Two options:
1. If `harness-creator` skill is available — invoke it to bootstrap infrastructure, then return to Step 1.
2. If `harness-creator` is unavailable — tell the user: "This project lacks harness infrastructure (AGENTS.md missing). I can continue, but without layer rules, dependency checks, or architecture guidance." Then proceed as a normal coding task.
