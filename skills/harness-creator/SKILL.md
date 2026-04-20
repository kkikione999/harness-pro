---
name: harness-creator
description: Analyze a codebase and generate harness infrastructure (AGENTS.md, docs/, scripts/, harness/ directories, layer rules). Use when user wants to set up, bootstrap, or initialize harness infrastructure for their project. Also use when auditing an existing project or improving harness coverage. Multi-language: TypeScript, Go, Python, Swift.
---

# Harness Creator

Analyzes a codebase and generates the infrastructure for reliable AI Agent collaboration.

## Two Modes

### Initial Mode (AGENTS.md missing)
1. **Audit** → Score codebase 0-100
2. **Generate** → Create infrastructure based on score
3. **Report** → Summarize what was created

### Improve Mode (AGENTS.md exists)
1. **Audit** → Re-score codebase
2. **Gap Analysis** → Find missing/outdated items
3. **Update** → Fix gaps only

## Audit Dimensions

| Dimension | Weight | What to Check |
|-----------|--------|---------------|
| Documentation | 25% | AGENTS.md, docs/ARCHITECTURE.md, docs/DEVELOPMENT.md |
| Lint Coverage | 35% | lint-deps, lint-quality scripts |
| Validation | 25% | validate.py, build/test steps |
| Harness | 15% | harness/ directory structure |

## Scoring

| Score | Status | Action |
|-------|--------|--------|
| 0-20 | Bare metal | Generate everything |
| 21-70 | Partial | Fill gaps |
| 71+ | Healthy | Minor fixes |

## Workflow

### Step 1: Detect Mode
```
if AGENTS.md exists → Improve Mode
else → Initial Mode
```

### Step 2: Audit
- Read `references/audit.md` for detailed scoring logic
- Scan for language (detect from go.mod, package.json, Package.swift, etc.)
- Analyze imports to infer layer mapping

### Step 3: Generate or Improve
- Read `references/generator.md` for generation logic
- Read `references/layer-rules.md` for layer definitions
- Read language-specific template from `references/templates/`

### Step 4: Verify
- Run lint-deps to ensure generated scripts work
- Run validate.py if project builds

## Key Files to Create

1. **AGENTS.md** — ≤100 lines, MAP only (index to docs, not a manual)
2. **docs/ARCHITECTURE.md** — Layer diagram, package responsibilities
3. **docs/DEVELOPMENT.md** — Build/test commands, common tasks
4. **scripts/lint-deps** — Layer dependency checker (educational errors required)
5. **scripts/lint-quality** — Code quality rules
6. **scripts/validate.py** — Unified validation entry point (MUST include verify step)
7. **E2E Verification** — `docs/E2E.md` (real-time interactive guide) OR `scripts/verify/` (script-based) — read `references/e2e-strategies.md` to determine mode
8. **harness/** — tasks/, trace/, memory/ directories

## Core Principles to Include in AGENTS.md

The generated AGENTS.md MUST include these principles (adapt wording per project):

1. **Repository is the only source of truth** - All rules live in Git, not chat history
2. **Coordinator never writes code** - For tasks needing >1 file changes, delegate to sub-agents
3. **Validate before acting** - Run lint-deps before creating files in new locations or adding cross-module imports
4. **Context is expensive** - Keep sub-agent prompts focused; avoid giant context

## Layer Rules

Read `references/layer-rules.md` for:
- Layer definitions (L0-L4+, including Layer 2 for config)
- How to infer layers from imports
- **How to write educational error messages** (error = what + which rule + why wrong + how to fix)
