# E2E Verification Strategies

How to detect the right E2E verification mode for a project and generate appropriate artifacts.

## Detection Flow

```
1. Detect project type (existing logic: go.mod, Package.swift, package.json, etc.)
2. Detect available E2E tools:
   a. Check MCP server availability (Chrome DevTools, Playwright, Mobile Agent, etc.)
   b. Check test framework dependencies in project config
   c. Check if the system has a runnable interface (CLI, HTTP, UI)
3. Determine E2E mode
```

## Three E2E Modes

### Mode 1: Real-time Interactive

**When**: An MCP tool can directly interact with the running system's UI.

Detection signals:
- Web frontend + Chrome DevTools MCP / Playwright MCP available
- Any project where a real-time interaction tool is already wired up

**Creator output**: `docs/E2E.md`

```markdown
# E2E Verification Guide

## Available Tools
- {tool name}: {what it can do}

## Core User Paths
1. {Path name}: {step-by-step using the tool}
   - Navigate to {url/screen}
   - Interact with {element}
   - Verify {outcome}

## How to Verify
For each task that changes UI behavior:
1. Read the user path below
2. Use {tool} to execute the steps
3. Confirm the expected outcome
```

Do NOT generate a `scripts/verify/run.py` for this mode — the verification happens in real-time through the tool, not via a batch script.

### Mode 2: Script Execution

**When**: The system can be verified by running commands or sending requests — no UI interaction needed.

Detection signals:
- CLI tool (main.go, click, commander, argparse)
- REST API (gin, express, fastapi, flask, Django REST)
- Library/package (no UI, no server — just function calls)

**Creator output**: `scripts/verify/run.py` (with real verification structure, not just TODO)

```python
#!/usr/bin/env python3
"""E2E verification for {project_name}."""

import subprocess
import sys


def run_cmd(cmd, description):
    """Run a command and report result."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    status = "PASS" if result.returncode == 0 else "FAIL"
    print(f"[{status}] {description}")
    if result.returncode != 0 and result.stderr:
        print(f"  Error: {result.stderr[:200]}")
    return result.returncode == 0


def verify_cli():
    """Verify CLI commands work correctly."""
    # TODO: Fill in actual commands and expected behavior
    # Example:
    # run_cmd("mycli --version", "Version command exits 0")
    # run_cmd("mycli add-user --name test", "Add user succeeds")
    return True


def verify_api():
    """Verify API endpoints respond correctly."""
    # TODO: Fill in actual requests and assertions
    # Example:
    # run_cmd("curl -s http://localhost:8080/health", "Health check returns 200")
    return True


def main():
    print("E2E Verification")
    print("=" * 40)
    all_pass = True
    # TODO: Uncomment the verifications that apply
    # all_pass &= verify_cli()
    # all_pass &= verify_api()
    print(f"\nResult: {'ALL PASS' if all_pass else 'FAILED'}")
    sys.exit(0 if all_pass else 1)


if __name__ == "__main__":
    main()
```

### Mode 3: Needs Scaffolding

**When**: The system has a UI but no MCP tool can directly interact with it. Screenshot-based verification is the only option and is too inefficient.

Detection signals:
- iOS app (.xcodeproj, .xcworkspace, Package.swift with SwiftUI)
- Android app (build.gradle + AndroidManifest.xml)
- Desktop app (Electron without Chrome DevTools access, native desktop)
- Any UI project where no interactive MCP tool is available

**Creator output**: `docs/E2E.md` + scaffolding guidance

```markdown
# E2E Verification Guide

## Current Limitation
This project has a UI but no real-time interaction tool is available.
Screenshot-based verification is possible but inefficient.

## Scaffolding Recommendations

### Option A: {Recommended approach based on project type}
{Description of what to build — e.g., accessibility identifiers, view hierarchy dump, test target}

Steps to set up:
1. {Step 1}
2. {Step 2}
3. After setup, return here and update the verification paths below

### Option B: {Alternative approach}
{Another viable option if A is too costly}

## Core User Paths (to be verified after scaffolding)
1. {Path name}: {description}
2. {Path name}: {description}

## How to Verify (after scaffolding is ready)
{Instructions for executor — will be filled in after scaffolding is built}
```

Creator should also generate any scaffolding CODE that is straightforward:
- For iOS: Generate an `AccessibilityIdentifiers.swift` file with constants for key UI elements
- For any project: Generate a minimal test target if none exists

If scaffolding requires significant project-specific decisions, creator flags it in `docs/E2E.md` and moves on — don't block the entire harness setup on E2E scaffolding.

## Mode Selection Logic

```python
def determine_e2e_mode(project_type, available_mcp_tools, system_interface):
    has_ui = project_type in ("web-frontend", "ios", "android", "desktop", "swift-ui")
    has_interactive_tool = any(
        tool in available_mcp_tools
        for tool in ["chrome-devtools", "playwright", "mobile-agent"]
    )
    can_script = system_interface in ("cli", "http-api", "library")

    if has_ui and has_interactive_tool:
        return "realtime"           # Mode 1
    elif can_script:
        return "script"             # Mode 2
    elif has_ui and not has_interactive_tool:
        return "needs-scaffolding"  # Mode 3
    else:
        return "script"             # Default: script mode with minimal verification
```

## What Creator Generates per Mode

| Mode | docs/E2E.md | scripts/verify/run.py | Scaffolding code |
|------|-------------|----------------------|------------------|
| Real-time Interactive | YES (tool guide + paths) | NO | NO |
| Script Execution | NO | YES (real structure) | NO |
| Needs Scaffolding | YES (scaffolding guide + paths) | NO | MAYBE (if straightforward) |

## Notes

- A project can have BOTH modes: API endpoints (script) + web UI (real-time). Creator should generate both artifacts and executor runs both.
- The scaffolding mode is inherently incomplete — creator gives direction, user/agent fills in the details. This is by design.
- Real-time verification is NOT a batch step in the pipeline — executor reads `docs/E2E.md` and follows the guide interactively during Step 6.
