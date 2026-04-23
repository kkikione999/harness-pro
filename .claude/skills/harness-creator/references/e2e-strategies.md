# E2E Verification Strategies

How to determine how an AI Agent can verify its work, and what to generate.

## Two Verification Tiers

E2E verification has two tiers. Both should be generated when possible.

| Tier | Name | How | Purpose |
|------|------|-----|---------|
| 1 | **Scripted** | Pre-written scripts, batch execution | CI, pre-commit, regression |
| 2 | **Live Test** | Agent interacts with running system in real-time | Development, feature verification, ad-hoc testing |

Scripted catches regressions. Live Test lets Agent verify interactively. Neither replaces the other.

## Tier 1: Scripted Verification

Pre-written verification that runs without Agent intervention. Smoke tests, integration tests, architecture checks.

### Detection

| Signal | Status |
|--------|--------|
| Project builds | Can run compile checks |
| Test runner exists (`swift test`, `go test`, `npm test`, `pytest`) | Can run unit/integration tests |
| Shell scripts can probe the system | Can create verify scripts |

### What Creator Generates

`docs/E2E.md` includes a **Tier 1: Scripted Verification** section with:
- Build/test/lint commands
- What each command verifies
- How to run the full validation pipeline (`validate.py`)

## Tier 2: Live Test

Agent controls the running system in real-time through programmatic interfaces.
**No screenshots, no visual element location** — purely identifier-based or command-based interaction.

### Core Requirements

Two capabilities must be present for Live Test:

1. **Observe** — Agent can see what the system is doing RIGHT NOW
2. **Control** — Agent can operate the system in REAL-TIME

Both must be non-visual: identifier-based, command-based, or API-based.

### Detection: Project Type → Live Test Readiness

| Project Type | Live Test Method | Ready? |
|-------------|-----------------|--------|
| Web + Browser MCP | a11y snapshot → click/fill by UID | ✅ Ready |
| CLI tool | Run command → read stdout/stderr | ✅ Ready |
| HTTP API | curl/fetch → read response | ✅ Ready |
| Native macOS + App MCP Bridge | Accessibility API via MCP server | ⚠️ Needs scaffolding |
| Native macOS, no bridge | Cannot live test | ❌ Generate scaffolding plan |

### Observe Detection

| Signal | Method | Non-visual? |
|--------|--------|-------------|
| Web UI + Browser MCP | `take_snapshot` → a11y tree with UIDs | ✅ |
| CLI tool | Read stdout/stderr from commands | ✅ |
| HTTP API | Read response body + status code | ✅ |
| Native app + App MCP | Query view hierarchy via accessibility API | ✅ |
| Native app, no MCP | Cannot observe in real-time | ❌ |
| Screenshot-based observation only | Not acceptable for Live Test | ❌ |

### Control Detection

| Signal | Method | Non-visual? |
|--------|--------|-------------|
| Web UI + Browser MCP | `click(uid)`, `fill(uid, val)` | ✅ |
| CLI tool | Run commands with arguments | ✅ |
| HTTP API | Send requests (curl, fetch) | ✅ |
| Native app + App MCP | AXUIElement actions by identifier | ✅ |
| Native app, no MCP | Cannot control in real-time | ❌ |
| Coordinate-based clicking | Not acceptable for Live Test | ❌ |

## Generation Logic

### Decision Tree

```
1. Check Tier 1 (Scripted):
   ├─ Build + test work → Generate scripted section in E2E.md
   └─ Cannot build → Skip scripted, note in report

2. Check Tier 2 (Live Test):
   ├─ Web/CLI/API project → Ready
   │   → Generate live test section with concrete MCP tool calls
   │
   ├─ Native app + App MCP Bridge exists → Ready
   │   → Generate live test section with MCP tool calls
   │
   └─ Native app, no MCP Bridge → Not ready
       → Generate:
         - docs/E2E.md with gap analysis
         - docs/exec-plans/add-live-test-scaffolding.md

3. Combine both tiers into docs/E2E.md
```

### docs/E2E.md Template (Both Tiers Ready)

```markdown
# E2E Verification Guide

## Tier 1: Scripted Verification

### Commands
- `{build command}` — Build check
- `{test command}` — Run tests
- `./scripts/lint-deps` — Layer dependency check
- `./scripts/lint-quality` — Code quality check
- `python3 scripts/validate.py` — Full pipeline

### What's Covered
{List what each scripted step verifies}

## Tier 2: Live Test

### How to Observe
{Concrete method, e.g.:}
{Web: `mcp__chrome-devtools__take_snapshot` returns a11y tree with UIDs}
{CLI: Read stdout from running command}
{API: `curl -s http://localhost:8080/api/status | jq .status`}

### How to Control
{Concrete method, e.g.:}
{Web: `mcp__chrome-devtools__click` with uid from snapshot}
{CLI: Run command with specific arguments}
{API: `curl -X POST http://localhost:8080/api/action -d '{payload}'`}

### Core User Paths
1. {Path name}
   - Control: {step-by-step with concrete tool calls and identifiers}
   - Observe: {expected outcome + concrete check command}
2. {Path name}
   ...
```

### docs/E2E.md Template (Live Test Needs Scaffolding)

```markdown
# E2E Verification Guide

## Tier 1: Scripted Verification
{Same as above — Tier 1 is independent of Tier 2 readiness}

## Tier 2: Live Test

### Current State
- Observe: {what works today, e.g., "CGWindowListCopyWindowInfo can see windows"}
- Control: {what works today, e.g., "No real-time control available"}

### Gap
{Specific missing capability, e.g.:}
{"No MCP bridge to interact with native macOS UI elements in real-time."}
{"Accessibility identifiers exist but no tool consumes them for live interaction."}

### How to Verify (after scaffolding)
{Description of how live test will work once scaffolding is built}

### Core User Paths
{Same paths, annotated with which steps are verifiable now vs need scaffolding}
```

Scaffolding plan generated at `docs/exec-plans/add-live-test-scaffolding.md`. See "Native App MCP Bridge Scaffolding" section below for template.

### Concrete Method Requirements

Creator MUST fill in real, concrete methods. Not vague descriptions.

| Bad (vague) | Good (concrete) |
|-------------|-----------------|
| "check the UI" | `mcp__chrome-devtools__take_snapshot` then find uid `status-text` |
| "interact with the app" | `mcp__chrome-devtools__click` uid `submit-btn` |
| "verify it works" | `curl -s http://localhost:8080/health \| jq .status` returns `"ok"` |
| "click the button" | `mcp__playwright__browser_click ref=save-button` |

## Native App MCP Bridge Scaffolding

### When to Generate

When project is a native app (macOS/iOS/Android) and no MCP bridge exists for real-time interaction.

### What is the MCP Bridge

An MCP server that wraps platform accessibility APIs, enabling Agent real-time interaction with native UI elements — identified by accessibility identifier, not by visual position.

### Required Tool Capabilities

| Tool | Purpose | Non-visual Method |
|------|---------|-------------------|
| `take_snapshot` | Get UI hierarchy as text tree with identifiers | Accessibility API query |
| `click(identifier)` | Click UI element by identifier | AXUIElementPerformAction |
| `type_text(text)` | Type text via keyboard | CGEvent keyboard simulation |
| `get_value(identifier)` | Read element value/label/text | AXUIElementCopyAttributeValue |
| `wait_for(text)` | Wait for specific text to appear | Poll accessibility tree |
| `element_exists(identifier)` | Check if element is present | Query accessibility hierarchy |

### Scaffolding Plan Template

Generate at `docs/exec-plans/add-live-test-scaffolding.md`:

```markdown
# Plan: Add Live Test Scaffolding

## Goal
Enable AI Agent to interact with {project_name} in real-time via MCP tools,
using accessibility identifiers (non-visual, programmatic targeting).

## Prerequisites
- [ ] Accessibility identifiers defined in code
- [ ] Identifiers wired into views (.accessibilityIdentifier() or equivalent)
- [ ] App launches and runs with identifiable elements

## What to Build

### 1. Native App MCP Server
- Location: `{project}/tools/{name}-mcp-server/`
- Tech: {Swift/Python/Node} wrapping platform Accessibility API
- Must expose these tools:
  - `take_snapshot` → return UI hierarchy as text (identifier + type + label)
  - `click(identifier)` → find element by ID, perform press/action
  - `type_text(text)` → focus element, simulate keyboard input
  - `get_value(identifier)` → read element's display value
  - `wait_for(text, timeout)` → poll until text appears in hierarchy
  - `element_exists(identifier)` → boolean check

### 2. Platform Implementation Details

#### macOS (AXUIElement)
- `AXUIElementCreateApplication(pid)` → get app root
- `AXUIElementCopyAttributeValue(el, kAXChildrenAttribute)` → traverse tree
- `AXUIElementCopyAttributeValue(el, kAXIdentifierAttribute)` → match identifiers
- `AXUIElementPerformAction(el, kAXPressAction)` → click buttons
- `AXUIElementSetValue(el, kAXValueAttribute, value)` → set values
- CGEvent for keyboard simulation

#### iOS (XCTest / Device MCP)
- Use XCTest framework's XCUIElement API
- Or integrate with existing Device MCP tools

#### Android (AccessibilityNodeInfo)
- Use Android Accessibility Service
- UiAutomator for element interaction

### 3. Claude Code Integration
- Register MCP server in `.claude/settings.json` or `.claude/settings.local.json`:
  ```json
  {
    "mcpServers": {
      "{name}-app": {
        "command": "{path-to-server}",
        "args": ["--app-bundle-id", "{bundle_id}"]
      }
    }
  }
  ```

### 4. E2E.md Update
After MCP server is verified working:
- Replace Tier 2 gap section with concrete live test methods
- Add MCP tool calls for each core user path
- Update "How to Observe" and "How to Control" with real tool names

## Core User Paths to Unlock
{List paths from E2E.md that currently cannot be live-tested}

## Verification Steps
1. Start the app: `open -a {app_name}`
2. Agent runs `take_snapshot` → sees accessibility tree with identifiers
3. Agent runs `click("{identifier}")` → element is activated
4. Agent runs `get_value("{identifier}")` → reads expected text
5. Agent follows a core user path end-to-end using live test methods
```

## What Creator Does NOT Generate

- **MCP server code** — Executor builds this from the scaffolding plan
- **Scaffolding code** (AccessibilityIdentifiers, test targets, MCP server) — Executor builds these
- **Verify batch scripts** (`scripts/verify/run.py`) — Live test is Agent-driven, not scripted
- **Multiple E2E.md files** — Always one `docs/E2E.md` combining both tiers
- **Visual/screenshot-based verification methods** — Live test must be identifier-based

## Quality Checklist

Before finishing E2E.md, verify:

### Tier 1: Scripted
- [ ] Build command is correct for the language
- [ ] Test command is correct for the language
- [ ] Lint commands are referenced
- [ ] validate.py pipeline is documented

### Tier 2: Live Test
- [ ] Observe method is concrete (specific tool/command, not "check the UI")
- [ ] Control method is concrete (specific action, not "interact with app")
- [ ] Each user path has step-by-step control instructions with identifiers
- [ ] Each user path has observable expected outcome
- [ ] If gap exists, scaffolding plan describes what MCP bridge to build
- [ ] **No visual/screenshot-based element targeting** in live test methods
- [ ] All element references use identifiers (accessibility ID, DOM UID, selector), not coordinates or visual descriptions

### Scaffolding Plan (if generated)
- [ ] Describes exactly what MCP tools to build
- [ ] Includes platform-specific implementation details
- [ ] Lists prerequisites (accessibility identifiers must exist first)
- [ ] Describes how to verify the scaffolding works
- [ ] Lists which user paths the scaffolding unlocks
