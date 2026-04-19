# AGENTS.md - MarkdownPreview Harness Map

## Core Principles (MUST follow)
- **Repository is only source of truth**: All rules, decisions, and patterns live in versioned files
- **Coordinator never writes code**: Planning, delegation, and synthesis only
- **Validate before acting**: Check "Is this legal?" before creating files or imports
- **Context is expensive**: Stay under 80% context window; use references for deep dives

## Project Structure
```
markdown-tool-bare/
├── Sources/MarkdownPreview/     # L0-L4 source code
├── Tests/MarkdownPreviewTests/   # Swift Testing suite
├── scripts/                     # Build, lint, verify scripts
├── harness/                     # Harness infrastructure (tasks/memory/trace)
└── docs/                        # Architecture & development docs
```

## Layer Rules (Dependency Direction)
```
L4 (Interface)   ← AppWindowManager, ContentView, AppDelegate, MarkdownPreviewApp
L3 (Services)     ← AppState, MarkdownInteractions
L2 (Config)       ← (none in this project)
L1 (Utils)       ← ReadOnlyTextView
L0 (Types)        ← MarkdownFileType, MarkdownRenderMode, LinkHandling
```
**Rule**: Higher layers MAY import lower layers; lower layers MUST NOT import higher.

## Entry Points
- **Build**: `swift build` or `swift build --configuration release`
- **Test**: `swift test`
- **Verify (E2E)**: `python3 scripts/validate.py`
- **Register default handler**: `swift scripts/set_default_handler.swift <app-path>`

## Quick Reference
- **Lint Deps**: `scripts/lint-deps` - enforces L0→L4 direction
- **Lint Quality**: `scripts/lint-quality` - file length, no print(), @MainActor L4
- **Validate**: `scripts/validate.py` - build → lint-arch → lint-quality → test → verify
