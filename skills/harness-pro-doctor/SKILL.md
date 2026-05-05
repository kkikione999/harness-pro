---
name: harness-pro-doctor
description: >
  Health-check skill for the harness-pro plugin. Runs a one-time diagnostic that
  verifies all plugin components are correctly installed: LSP servers, MCP server
  (utell-ios), required runtimes (uv/python/node), and plugin data directory.
  Use when the user types "/harness-pro-doctor" or asks to check plugin health.
  This skill is READ-ONLY — it never installs or modifies anything.
---

# harness-pro-doctor

Run a series of checks and report a pass/fail summary. Do NOT attempt any fixes or installations.

## Checks

Run each check below with Bash. Collect results and present a single summary table at the end.

### 1. Runtimes

| Check | Command |
|-------|---------|
| Node.js (for LSP) | `command -v node && node --version` |
| npm (for LSP) | `command -v npm && npm --version` |
| Go (for gopls) | `command -v go && go version` |
| uv (preferred Python runner) | `command -v uv && uv --version` |
| Python 3.10+ (fallback) | `python3 --version` (verify >= 3.10) |

### 2. LSP Servers

| Check | Command | Also installable by |
|-------|---------|---------------------|
| typescript-language-server | `command -v typescript-language-server && typescript-language-server --version` | `npm i -g typescript-language-server typescript` |
| sourcekit-lsp | `command -v sourcekit-lsp` | Xcode CLI tools: `xcode-select --install` |
| gopls | `command -v gopls && gopls version` | `go install golang.org/x/tools/gopls@latest` |
| pyright | `command -v pyright-langserver && pyright --version` | `npm i -g pyright` |

### 3. MCP Server (utell-ios)

| Check | Command |
|-------|---------|
| Plugin root exists | `test -d "$CLAUDE_PLUGIN_ROOT"` |
| run.sh exists and executable | `test -x "$CLAUDE_PLUGIN_ROOT/mcp/utell-ios/run.sh"` |
| pyproject.toml exists | `test -f "$CLAUDE_PLUGIN_ROOT/mcp/utell-ios/pyproject.toml"` |
| uv.lock exists | `test -f "$CLAUDE_PLUGIN_ROOT/mcp/utell-ios/uv.lock"` |
| venv exists | `test -d "$CLAUDE_PLUGIN_ROOT/mcp/utell-ios/.venv"` |
| venv Python importable | `"$CLAUDE_PLUGIN_ROOT/mcp/utell-ios/.venv/bin/python" -c "import mcp; print(f'mcp {mcp.__version__}')"` |
| utell_ios module importable | `"$CLAUDE_PLUGIN_ROOT/mcp/utell-ios/.venv/bin/python" -c "import utell_ios"` |

### 4. Plugin Data Directory

| Check | Command |
|-------|---------|
| Data dir exists | `test -d "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/harness-pro-plugin}"` |
| LSP state file | `test -f "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/harness-pro-plugin}/.lsp-installed"` |

### 5. Hooks

| Check | Command |
|-------|---------|
| hooks.json valid JSON | `python3 -c "import json; json.load(open('$CLAUDE_PLUGIN_ROOT/hooks/hooks.json'))"` |

## Output Format

Present results as a single table:

```
Category       Check                        Status    Detail
───────────── ──────────────────────────── ───────── ───────────────────
Runtime        Node.js                      ✓ OK      v20.11.0
Runtime        uv                           ✓ OK      0.9.26
...
LSP            typescript-language-server   ✗ MISSING  → npm i -g typescript-language-server typescript
LSP            gopls                        ✓ OK      v0.15.0
...
MCP            utell-ios venv               ✓ OK      .venv (66 packages)
MCP            mcp SDK                      ✓ OK      mcp 1.2.0
...
```

At the end, if any check failed, print:

```
⚠  N issue(s) found. To fix missing LSP servers, run:
   npm i -g typescript-language-server typescript pyright
   go install golang.org/x/tools/gopls@latest
   xcode-select --install   # for sourcekit-lsp
```

If all pass:

```
✓  All harness-pro-plugin components healthy.
```
