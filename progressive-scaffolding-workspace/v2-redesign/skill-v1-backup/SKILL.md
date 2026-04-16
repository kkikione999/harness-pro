---
name: progressive-scaffolding
description: >
  Build controllability and observability scaffolding for software projects, then package as a reusable skill.
  Use when the user wants to: add observability to a code project, create an autonomous feedback loop for AI agents,
  enable self-verifying code for agents, assess a project's scaffolding state, generate control scripts,
  or build project-specific agent skills. Supports two modes: ASSESS-ONLY (just analyze gaps, no generation)
  and full REFINE LOOP (ASSESS → GENERATE → RE-ASSESS → REFINE → PACKAGE). **IMPORTANT**: For content
  repositories (markdown docs, blogs, knowledge bases), use progressive-docs instead. This skill is for
  SOFTWARE PROJECTS only (code with build systems). Triggers on phrases like "add scaffolding",
  "make project agent-friendly", "controllable", "observable", "agent harness", "self-verifying",
  "observability framework", "controllability framework", "assess scaffolding", "gap analysis",
  "progressive-scaffolding".
---

# Progressive Scaffolding

Build a project's controllability and observability scaffolding so AI agents can control, observe, and verify code autonomously — without human intervention.

**IMPORTANT**: This skill is for **software projects** (code with build systems: npm, go, cargo, Makefile, etc.).
For content repositories (markdown files, documentation, knowledge bases), use **progressive-docs** instead.

## Core Insight

For an agent to work autonomously on a project, it needs:

```
Controllability = Agent can execute, intervene, input, and orchestrate
Observability   = Agent can see feedback, persist logs, query history, and attribute causes
Verification    = Agent can verify success automatically
```

The goal: bring every project to "usable" state (all dimensions ≥ Level 2), then package as a skill the agent can reuse.

## The REFINE LOOP

```
┌─────────────────────────────────────────────────────────────┐
│  1. ASSESS     → Probe project → Assessment report          │
│  2. GENERATE   → Generate scaffolding based on gaps         │
│  3. RE-ASSESS  → Probe scaffolding → Verify improvements    │
│  4. REFINE     → If not usable, fix gaps → RE-ASSESS       │
│  5. PACKAGE    → skill-creator → project-specific skill     │
└─────────────────────────────────────────────────────────────┘
```

**Usable standard**: All 9 dimensions (E1-E4, O1-O4, V1-V3) must reach Level 2.

### Fast Path: ASSESS-ONLY Mode

When the user only wants to understand the project's current scaffolding state (not generate anything), use ASSESS-ONLY mode. This skips the GENERATE/RE-ASSESS/REFINE loop entirely.

**Trigger phrases**: "assess", "what's missing", "evaluate", "check scaffolding state", "gap analysis"

In ASSESS-ONLY mode:
1. Run Step 1.0 (pre-check) → Step 1.1 (detect type) → Step 1.2 (probes) → Step 1.3 (report)
2. Add a **Priority Gaps** section listing the top 3-5 gaps ranked by impact
3. Stop — do not proceed to GENERATE unless the user asks

---

## Phase 1: ASSESS

### Step 1.0: Pre-Check — Is This a Software Project?

**CRITICAL**: Before anything else, check if this is a software project or a content repository.

A software project has:
- Build system (package.json, go.mod, Cargo.toml, Makefile, etc.)
- Source code files (.js, .go, .rs, .py, etc.)
- Test infrastructure

A content repository has:
- Mostly markdown files (.md)
- No build system for code
- Documentation focus

**If content repository detected**: Stop and recommend using **progressive-docs** instead.
Say: "This appears to be a content repository (markdown files). For documentation projects, use progressive-docs instead. progressive-scaffolding is for software projects with build systems."

### Step 1.1: Detect Project Type

Run `scripts/detect-project-type.sh` to determine the project category:

```bash
./scripts/detect-project-type.sh /path/to/project
```

Output: `backend` | `mobile` | `cli` | `embedded` | `desktop`

### Step 1.2: Run Probes

Run all probe scripts to assess current state:

```bash
# E1-E4 Controllability
./scripts/detect-controllability.sh /path/to/project

# O1-O4 Observability
./scripts/detect-observability.sh /path/to/project

# V1-V3 Verification
./scripts/detect-verification.sh /path/to/project
```

### Step 1.3: Generate Assessment Report

Run `scripts/generate-report.sh` to produce `assessment-report.md`:

```bash
./scripts/generate-report.sh /path/to/project
```

The report includes:
- Current levels for all 9 dimensions (E1-E4, O1-O4, V1-V3)
- Evidence supporting each assessment
- Gap list with specific improvement suggestions

---

## Phase 2: GENERATE

### Step 2.1: Select Template

Based on project type from Step 1.1, load the appropriate template set:

| Project Type | Template Path |
|-------------|---------------|
| backend | `templates/backend/` |
| mobile | `templates/mobile/` |
| cli | `templates/cli/` |
| embedded | `templates/embedded/` |

### Step 2.2: Fill Templates

For each gap identified in the assessment report, fill the corresponding mustache template:

```bash
# Generate scaffolding
./scripts/generate-scaffolding.sh /path/to/project --type [backend|mobile|cli|embedded]
```

This produces:

```
[project-root]/.harness/
├── controllability/
│   ├── Makefile                  # make run, test, verify, test-auto, lint, deps
│   ├── start.sh                  # start the service/process
│   ├── stop.sh                   # stop the service/process
│   ├── verify.sh                 # health check script
│   ├── test-auto.sh              # automated test + result parser
│   ├── lint-import-direction.sh  # enforce module layer hierarchy
│   └── analyze-deps.sh           # dependency graph + cycle detection
├── observability/
│   ├── log.sh                    # structured log query
│   ├── metrics.sh                # metrics endpoint query
│   ├── health.sh                 # health check
│   └── trace.sh                  # correlation-id injection
├── ci/
│   └── ci-pipeline.yml           # GitHub Actions CI (copy to .github/workflows/)
└── assessment-report.md          # Phase 1 output
```

### Step 2.3: Verify Template Selection

If the project has mixed characteristics (e.g., backend with CLI tooling), combine templates as needed. The `detect-project-type.sh` script outputs confidence scores — if any score is >0.3, use multiple template sets.

---

## Phase 3: RE-ASSESS

After scaffolding is generated, run probes again to verify improvements:

```bash
./scripts/reassess.sh /path/to/project
```

This time probes check `.harness/` directory for scaffolding existence and functionality.

### RE-ASSESS Report

```
## RE-ASSESS Results

| Dimension | Previous | Current | Change |
|-----------|----------|---------|--------|
| E1        | Level 1  | Level 2 | +1 ✅  |
| E2        | Level 1  | Level 1 | 0 ❌  |
| ...       | ...      | ...     | ...    |

### Remaining Gaps
- E2: Still missing [X], need to add [Y]
```

---

## Phase 4: REFINE

If any dimension is still below Level 2, iterate:

```
RE-ASSESS not "usable"
    ↓
Identify lowest-scoring dimensions
    ↓
GENERATE additional scaffolding for those dimensions
    ↓
RE-ASSESS again
    ↓
Loop until all dimensions ≥ Level 2
```

**Maximum iterations**: 5 (after 5 failed attempts, report failure and suggest manual intervention)

---

## Phase 5: PACKAGE

When all dimensions reach Level 2, use skill-creator to package:

```bash
# Package scaffolding as a reusable skill
python3 ~/.claude/plugins/cache/claude-plugins-official/skill-creator/b091cb4179d3/skills/skill-creator/scripts/package_skill.py \
  --input .harness \
  --name "[project-name]-ctrl" \
  --output ~/.claude/skills/[project-name]-ctrl
```

This creates a project-specific skill at `~/.claude/skills/[project-name]-ctrl/SKILL.md`.

### Generated Skill Format

```markdown
---
name: [project-name]-ctrl
description: Controllability + Observability skill for [project-name]
---

# [Project Name] Control Skill

## Capability Levels
- Controllability: Level 2
- Observability: Level 2
- Verification: Level 2

## Available Commands
- `make run` — Start service
- `make stop` — Stop service
- `make verify` — Health check
- `make test-auto` — Automated test + parse results

## Observability
- Logs: `.harness/observability/log.sh`
- Metrics: `.harness/observability/metrics.sh`
- Health: `.harness/observability/health.sh`

## Agent Usage
When working on this project, load this skill to get control interfaces.
```

---

## Assessment Dimensions (Reference)

### Controllability (E1-E4)

| Dimension | Description | Level 1 | Level 2 | Level 3 |
|-----------|-------------|---------|---------|---------|
| **E1 Execute** | Agent can trigger code execution | bash/shell | build system (Makefile/npm/go) | sandboxed execution |
| **E2 Intervene** | Agent can modify system state | read-only | can write files/configs | can restart processes/services |
| **E3 Input** | Agent can inject data into system | manual only | env vars / config files | runtime injection |
| **E4 Orchestrate** | Agent can execute multi-step flows | manual multi-step | scripted sequences | automated pipelines |

### Observability (O1-O4)

| Dimension | Description | Level 1 | Level 2 | Level 3 |
|-----------|-------------|---------|---------|---------|
| **O1 Feedback** | System outputs information | stdout/stderr | structured output | typed/outputs (JSON) |
| **O2 Persist** | Information is retained | in-memory only | log files | queryable storage |
| **O3 Queryable** | History can be searched | none | grep/cat logs | log aggregation (LogQL) |
| **O4 Attribute** | Causes can be traced to results | none | request IDs | full correlation IDs |

### Verification (V1-V3)

| Dimension | Description | Level 1 | Level 2 | Level 3 |
|-----------|-------------|---------|---------|---------|
| **V1 Exit Code** | System reports success/failure | exit codes | typed exit codes | semantic exit (0=pass, >0=error-type) |
| **V2 Semantic** | Output can be parsed | raw text | structured text | machine-readable (JSON) |
| **V3 Automated** | Verification runs without human | manual | scripted | auto-trigger on changes |

---

## Interaction Pattern

1. **Pre-Check**: Is this a software project or content repository?
   - Check for build system (package.json, go.mod, Makefile)
   - If content repo → recommend progressive-docs
2. **ASSESS**: Run probes → show assessment report → ask user to confirm gaps
   - If user only wanted assessment (ASSESS-ONLY mode), stop here with priority gaps
3. **GENERATE**: "Generate scaffolding for these gaps?" → generate → show what was created
4. **RE-ASSESS**: Automatically run after generation
5. **REFINE**: If not usable, "Continue refining?" → fix gaps
6. **PACKAGE**: "Package as skill?" → skill-creator packaging

**CRITICAL**: Always do Pre-Check first. progressive-scaffolding is for software projects only. Content repos need progressive-docs.

---

## Anti-Patterns

| Anti-Pattern | Why It Fails | Instead |
|-------------|--------------|---------|
| Generate without assessment | Can't measure improvement | Always ASSESS first |
| Claim Level 3 without evidence | Unrealistic expectations | Start at Level 2, grow organically |
| One-size-fits-all template | Projects differ too much | Use project-type detection + template mixing |
| Skip RE-ASSESS | Don't know if scaffolding works | Always verify after generating |
| Package before usable | Skill won't help agent | Ensure all dimensions ≥ Level 2 first |

---

## Script Reference

| Script | Purpose | Key Output |
|--------|---------|------------|
| `detect-project-type.sh` | Identify project category | `backend\|mobile\|cli\|embedded\|desktop` |
| `detect-controllability.sh` | Probe E1-E4 dimensions | `E1:LEVEL_N, E2:LEVEL_N...` |
| `detect-observability.sh` | Probe O1-O4 dimensions | `O1:LEVEL_N, O2:LEVEL_N...` |
| `detect-verification.sh` | Probe V1-V3 dimensions | `V1:LEVEL_N, V2:LEVEL_N...` |
| `generate-report.sh` | Create assessment report | `assessment-report.md` |
| `generate-scaffolding.sh` | Generate scaffolding | `.harness/controllability/`, `.harness/observability/` |
| `reassess.sh` | Re-run probes on scaffolding | Updated level assessments |

See `references/` for detailed probe logic and template documentation.
