# Generator Logic

How to generate or improve harness infrastructure.

## Generation Priority

Generate files in this order (dependencies matter):

1. **AGENTS.md** — Without this, nothing else matters (≤100 lines, MAP only)
2. **docs/ARCHITECTURE.md** — Defines layer structure (L0-L4+, include Layer 2 for config)
3. **docs/DEVELOPMENT.md** — Developer workflows
4. **scripts/lint-deps** — Enforces layer rules (educational errors required)
5. **scripts/lint-quality** — Enforces code quality
6. **scripts/validate.py** — Unified entry point (MUST include verify step)
7. **harness/** — Directory structure
8. **E2E Verification** — Read `references/e2e-strategies.md` → detect mode → generate `docs/E2E.md` or `scripts/verify/` or both

## AGENTS.md Template

**CRITICAL: Must be ≤100 lines. This is a MAP, not a manual.**

Structure (exactly this order):
```markdown
# <Project> Agent Guide

## Reading Path
- [Architecture](docs/ARCHITECTURE.md)
- [Development](docs/DEVELOPMENT.md)

## Build Commands
\`\`\`bash
swift build    # or: make build, go build, npm run build
swift test
./scripts/lint-deps
python3 scripts/validate.py
\`\`\`

## Layer Rules (The One Rule: Higher can import Lower, never the reverse)
Layer 0: types/       # No internal imports
Layer 1: utils/       # Import only L0
Layer 2: config/      # Import L0, L1
Layer 3: services/    # Import L0, L1, L2
Layer 4+: ui/ cli/    # Import any lower

## Core Principles
- **Repository is the only source of truth** - rules live in Git, not in chat
- **Coordinator never writes code** - delegate to workers for implementation
- **Validate before acting** - check layer rules before cross-module changes
- **Context is expensive** - prefer focused sub-agents over giant context
```

## docs/ARCHITECTURE.md Template

Include:
- Project overview
- Layer diagram (ASCII art)
- Key packages and responsibilities
- Dependency rules explanation
- External dependencies table

## docs/DEVELOPMENT.md Template

Include:
- Build commands
- Test commands
- Lint commands
- Common development tasks
- Project layout table
- TODO section for gaps

## scripts/lint-deps Template

```bash
#!/bin/bash
# Lint architecture: check layer dependencies

set -euo pipefail

# Layer mapping (auto-generated)
declare -A LAYERS=(
    ["pkg1"]=0
    ["pkg2"]=1
)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VIOLATIONS=0

# Educational error format (4 parts: WHAT, RULE, WHY WRONG, HOW TO FIX):
print_violation() {
    local source="$1" target="$2" src_layer="$3" tgt_layer="$4"
    echo "✗ VIOLATION FOUND"
    echo ""
    echo "File: $source (Layer $src_layer)"
    echo "Imports: $target (Layer $tgt_layer)"
    echo ""
    echo "THE RULE: Higher layers can import lower layers; lower CANNOT import higher."
    echo "WHY WRONG: Layer $src_layer depends on Layer $tgt_layer, breaking the dependency rule."
    echo ""
    echo "HOW TO FIX:"
    echo "  1. Move the dependency to a lower layer"
    echo "  2. Pass needed value as a parameter from the caller"
    echo "  3. Create a protocol/abstraction in an intermediate layer"
    echo ""
}

exit $VIOLATIONS
```

## scripts/lint-quality Template

```bash
#!/bin/bash
# Lint code quality rules

set -euo pipefail

MAX_LINES=500
VIOLATIONS=0

# Check 1: File line count
# Check 2: No print/console.log
# Check 3: Structured logging exists

exit $VIOLATIONS
```

## scripts/validate.py Template

```python
#!/usr/bin/env python3
"""Validate project consistency. Runs: build -> lint-arch -> lint-quality -> test -> verify."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent.parent


def run(name, cmd, cwd=None):
    """Run command, return True if success. Print truncated output."""
    if cwd is None:
        cwd = ROOT
    result = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True)
    status = "PASS" if result.returncode == 0 else "FAIL"
    print(f"[{status}] {name}")
    if result.stdout:
        print(result.stdout[:500] if len(result.stdout) > 500 else result.stdout)
    if result.stderr:
        print(result.stderr[:500] if len(result.stderr) > 500 else result.stderr, file=sys.stderr)
    return result.returncode == 0


def main():
    print("Validation Pipeline")
    print("=" * 60)

    steps = [
        ("Build", ["make", "build"]),  # or swift build, go build, etc.
        ("Lint Architecture", ["bash", "scripts/lint-deps"]),
        ("Lint Quality", ["bash", "scripts/lint-quality"]),
        ("Test", ["make", "test"]),
        ("Verify (E2E)", ["python3", "scripts/verify/run.py"]),  # E2E verification
    ]

    passed = sum(1 for name, cmd in steps if run(name, cmd))
    total = len(steps)

    print(f"\n{'=' * 60}")
    print(f"Passed: {passed}/{total}")
    if passed == total:
        print("All validations passed!")
    sys.exit(0 if passed == total else 1)


if __name__ == "__main__":
    main()
```

## E2E Verification Generation

Read `references/e2e-strategies.md` for the full framework. Summary:

### Step 1: Detect E2E Mode

Check project type and available tools:

```python
def detect_e2e_mode(project_type, available_mcp_tools):
    has_ui = project_type has a user interface
    has_interactive_tool = Chrome DevTools MCP / Playwright MCP / etc. available
    can_script = system has CLI or HTTP interface

    if has_ui and has_interactive_tool → "realtime"
    elif can_script → "script"
    elif has_ui → "needs-scaffolding"
```

### Step 2: Generate Artifacts by Mode

| Mode | Generate |
|------|----------|
| Real-time Interactive | `docs/E2E.md` only (tool guide + core user paths) |
| Script Execution | `scripts/verify/run.py` (real structure, not just TODO) |
| Needs Scaffolding | `docs/E2E.md` (scaffolding direction + future paths) |

### Step 3: Update validate.py

If generating `scripts/verify/run.py`, ensure `scripts/validate.py` includes it in the pipeline.
If generating `docs/E2E.md` (real-time mode), `validate.py` should note that verify runs interactively.

### Mixed Mode

A project can need both (e.g., REST API + web UI). Generate both artifacts.

## harness/ Directory Structure

```
harness/
├── tasks/           # Task definitions
├── trace/
│   └── failures/   # Failure records (for Critic)
└── memory/        # Procedural & episodic memory
```

## Improve Mode Logic

When AGENTS.md exists:

1. **Read existing structure** — don't overwrite
2. **Check each file** — does it need update?
3. **Generate delta only** — update what changed
4. **Preserve customizations** — user's additions stay

```python
def improve(existing_files, audit_results):
    """Only generate/update what's missing or outdated."""
    for file, needs_update in audit_results.items():
        if needs_update:
            generate(file)

def should_update(existing, template):
    """Check if existing file needs update."""
    if not existing:
        return True
    # Compare structure, not line-by-line
    return missing_sections(existing, template)
```

## Quality Standards

### Error Message Quality

Good error = states what, which rule, why wrong, how to fix:

```
VIOLATION: services/user.go (Layer 3) imports ui/window.go (Layer 4).
Layer 3 packages must NOT import Layer 4 (interface layer).
This creates a circular dependency where business logic depends on UI.
Fix: Move the dependency to a lower layer, or pass the needed value as a parameter.
```

### Generated Code Quality

- Follow project's existing style (infer from existing files)
- Use proper imports
- Include TODO where user must fill in
- Don't leave broken stubs

## Multi-Language Considerations

| Language | lint-deps approach | Quality checks |
|----------|---------------------|----------------|
| Swift | Parse `import` statements | Check for `print()` |
| Go | `go list` + parse imports | Check for `fmt.Print` |
| TypeScript | Parse `import`/`from` | Check for `console.log` |
| Python | `ast` module or regex | Check for `print()` |

## Verification After Generation

After generating scripts:

1. Make them executable: `chmod +x scripts/lint-deps`
2. Run them: `./scripts/lint-deps`
3. Fix any issues in the generated scripts themselves
