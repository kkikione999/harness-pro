---
name: harness-executor
description: Execute development tasks within a Harness-managed project. Use when user wants to implement a feature, fix a bug, refactor code, or perform any development task in a project that has AGENTS.md. Triggers automatically when AGENTS.md exists. Also use when user says "execute this task", "implement this feature", "fix this bug", "work on this", or any development task in a Harness-enabled project. The executor follows an 8-step workflow: detect → load → plan → approve → execute → validate → cross-review → complete. It reads AGENTS.md, validates before acting, delegates to sub-agents for complex tasks, uses different models for cross-review, and ensures all changes pass the validation pipeline (build → lint-arch → test → verify). Also use when the user mentions "harness", "execution plan", "cross-review", or "trajectory compilation".
---

# Harness Executor

Executes development tasks within a Harness-managed project environment.

## Core Principle

> **Coordinator never writes code.** The executor coordinates, delegates, and validates — it does not directly modify source code for tasks requiring more than trivial changes.

## How It Works

```
┌─────────────────────────────────────────────────────────────┐
│                    EXECUTOR WORKFLOW                         │
├─────────────────────────────────────────────────────────────┤
│  1. DETECT       → Check AGENTS.md exists                   │
│  2. LOAD         → Read AGENTS.md + docs/                   │
│  3. PLAN         → Analyze complexity, make execution plan   │
│  4. APPROVE      → Human reviews plan (non-trivial tasks)   │
│  5. EXECUTE      → Delegate to sub-agents                   │
│  6. VALIDATE     → Run build → lint-arch → test → verify    │
│  7. CROSS_REVIEW → Different model reviews diff (medium+)   │
│  8. COMPLETE     → Git commit, write memory, summarize      │
└─────────────────────────────────────────────────────────────┘
```

## Step 1: Detect Environment

```
if [ -f "AGENTS.md" ]; then
    echo "Harness detected, proceeding..."
else
    echo "AGENTS.md not found. Invoking harness-creator..."
fi
```

If AGENTS.md is missing, invoke harness-creator to bootstrap infrastructure, then resume.

## Step 2: Load Context

Read these files to understand the project:

1. **AGENTS.md** — Entry point, layer rules, build commands
2. **docs/ARCHITECTURE.md** — Layer diagram, package responsibilities
3. **docs/DEVELOPMENT.md** — Build commands, common tasks

→ Also check `harness/memory/INDEX.md` for relevant patterns and past lessons.

## Step 3: Analyze Task Complexity

| Complexity | Criteria | Action |
|------------|----------|--------|
| **Simple** | Single file, typo fix, one-liner | Execute directly |
| **Medium** | Multi-file changes, consistent pattern | Plan → delegate to sub-agent |
| **Complex** | Refactoring, new modules, architecture changes | Sub-agent + worktree isolation |

### Complexity Decision Tree

```
Can you describe the task in one sentence without "and"?
├── YES → Simple: execute directly
└── NO → Does it affect multiple files consistently?
    ├── YES → Medium: plan + delegate
    └── NO → Complex: delegate + isolation
```

### Dynamic Complexity Escalation

During execution, if any signal fires, **immediately escalate**:

| Signal | Escalate To |
|--------|------------|
| Task touches >3 files unexpectedly | Medium → Complex |
| Cross-module import needed that wasn't planned | Medium → Complex |
| Simple task requires >2 files to change | Simple → Medium |
| Architectural decision needed mid-execution | Any → Complex |

On escalation: **stop**, update execution plan, re-approve with human if needed, then switch to sub-agent delegation.

## Step 4: Plan & Approve (Non-Trivial Tasks)

> **MANDATORY**: Before creating ANY plan, read **`PLANS.md`** in full. It contains behavioral guidelines that prevent common planning mistakes (over-scoping, vague conditions, missing boundaries).

For medium/complex tasks, create an execution plan at `docs/exec-plans/{task-name}.md`.

→ **Read `PLANS.md`** for plan creation behavioral guidelines (think before planning, simplicity first, surgical scope, goal-driven phases).
→ **Read `references/execution-plan.md`** for the full plan template and approval process.

**Wait for human approval** before proceeding to Step 5.

## Step 5: Execute

### Simple Tasks
Use direct execution (this is the ONLY case where coordinator writes code).

### Medium/Complex Tasks
**Delegate to sub-agents:**

```python
Agent(
    description="Execute: {task-name}",
    model="{haiku|sonnet|opus}",  # Based on complexity
    prompt="""Exact task description from plan
    Read: docs/ARCHITECTURE.md
    Read: docs/DEVELOPMENT.md
    Execute the assigned steps
    Validate after each major step
    Report back with diff + validation results"""
)
```

**Model selection:**
- `haiku` — Fast execution, simple changes
- `sonnet` — Medium complexity, code generation
- `opus` — Deep reasoning, refactoring, architecture

## Step 6: Validate (The Pipeline)

Run **in order**, stop on first failure:

```bash
# 1. Build        → {swift build | go build | npm build | make build}
# 2. Lint Arch    → ./scripts/lint-deps
# 3. Lint Quality → ./scripts/lint-quality
# 4. Test         → {swift test | go test | npm test | make test}
# 5. Verify (E2E) → python3 scripts/verify/run.py
```

→ **Read `references/validation.md`** for when to run each step, incremental validation based on impact scope, and the self-repair loop with context budget.

**Pre-validation rule:** Before creating files in new locations or adding cross-module imports, run `./scripts/lint-deps` to catch layer violations BEFORE they happen.

## Step 7: Cross-Review (Medium/Complex Tasks Only)

After mechanical validation passes, delegate review to a **different model** than the one that wrote the code. This catches logic issues that linters and tests miss.

Skip for: simple tasks, changes < 20 lines, auto-generated code.

→ **Read `references/cross-review.md`** for the review process, prompt template, and outcome handling.

## Step 8: Complete

### On Success
1. **Git**: Stage specific files, commit, optionally push/create PR
2. **Memory**: Write to `harness/memory/` (procedural if pattern repeated)
3. **Trace**: Write to `harness/trace/` (success record)
4. **Trajectory Check**: If success count ≥ 3 with consistent steps → suggest compilation
5. **Summarize**: "Completed {task}. Validated: build ✓, lint ✓, test ✓, verify ✓, review ✓"

### On Failure (Self-Repair Loop)
Analyze error → fix → re-validate. **Context budget: stop after ~40 tool calls or 3 attempts**, whichever comes first. On exhaustion: save to `harness/trace/failures/` and escalate to human.

→ **Read `references/completion.md`** for git workflow details, trajectory compilation trigger, and context-budget-aware repair loop.

## Checkpoints

For medium/complex tasks, save state at phase boundaries:
phase-1 (context-loaded) → phase-2 (plan-approved) → phase-3 (execution-complete) → phase-4 (validated) → phase-5 (reviewed)

→ **Read `references/checkpoint.md`** for checkpoint format and recovery process.

## Three Memory Types

| Type | Location | Purpose |
|------|----------|---------|
| **Episodic** | `harness/memory/episodic/` | Specific events and lessons |
| **Procedural** | `harness/memory/procedural/` | Successful operation patterns |
| **Failure** | `harness/trace/failures/` | Repeated failure patterns for Critic |

→ **Read `references/memory.md`** for formats, INDEX.md lookup system, and trajectory compilation trigger.

## Reading References

Load reference files only when needed — don't preload all of them.

| Reference | When to Read |
|-----------|-------------|
| `references/layer-rules.md` | Before adding cross-module imports |
| `references/validation.md` | During Step 6 (pipeline + incremental + repair) |
| `references/cross-review.md` | During Step 7 (review process) |
| `references/completion.md` | During Step 8 (git, trajectory, repair) |
| `PLANS.md` | **MANDATORY** — During Step 4 (before any planning) |
| `references/execution-plan.md` | During Step 4 (plan template) |
| `references/memory.md` | During Step 2 (lookup) and Step 8 (write) |
| `references/checkpoint.md` | When saving or recovering checkpoints |

## Integration with harness-creator

```
Executor starts → AGENTS.md missing?
    ├── YES → Invoke harness-creator → wait → resume
    └── NO  → Continue with normal workflow
```

## Key Files Used

| File | Purpose |
|------|---------|
| `AGENTS.md` | Entry point, layer rules, build commands |
| `docs/ARCHITECTURE.md` | Layer structure, package responsibilities |
| `docs/DEVELOPMENT.md` | Developer workflow, commands |
| `docs/exec-plans/` | Execution plan files |
| `scripts/lint-deps` | Layer dependency enforcement |
| `scripts/lint-quality` | Code quality enforcement |
| `scripts/validate.py` | Unified validation entry |
| `scripts/verify/run.py` | E2E verification |
| `scripts/{task-type}.sh` | Compiled trajectory scripts |
| `harness/memory/INDEX.md` | Memory index for quick lookup |

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Task completed, all validations + review passed |
| 1 | Validation failed (after self-repair attempts) |
| 2 | Task blocked by architecture/layer violation |
| 3 | Human rejected execution plan |
| 4 | Cross-review found CRITICAL issues (fix failed) |
| 5 | Context budget exhausted during repair loop |
| 127 | AGENTS.md missing and harness-creator unavailable |
