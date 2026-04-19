# MarkdownPreview Agent Guide

## Reading Path
- [Architecture](docs/ARCHITECTURE.md)
- [Development](docs/DEVELOPMENT.md)

## Build Commands
```bash
swift build
swift test
./scripts/lint-deps
python3 scripts/validate.py
```

## Layer Rules (The One Rule: Higher can import Lower, never the reverse)
```
L0: types/       # MarkdownFileType, MarkdownRenderMode - no internal imports
L1: utils/       # LinkHandling - imports only L0
L2: config/      # (not used in this project)
L3: services/    # MarkdownInteractions - imports L0, L1
L4+: interface/  # AppState, AppDelegate, AppWindowManager, Views - import any lower
```

## Core Principles
- **Repository is the only source of truth** - rules live in Git, not in chat history
- **Coordinator never writes code** - delegate to workers for tasks needing >1 file changes
- **Validate before acting** - run lint-deps before creating files in new locations or adding cross-module imports
- **Context is expensive** - prefer focused sub-agents over giant context

## Key Files
| Path | Purpose |
|------|---------|
| `Sources/MarkdownPreview/MarkdownFileType.swift` | L0 - File type definitions |
| `Sources/MarkdownPreview/MarkdownRenderMode.swift` | L0 - Render mode enum |
| `Sources/MarkdownPreview/LinkHandling.swift` | L1 - Link URL decision logic |
| `Sources/MarkdownPreview/MarkdownInteractions.swift` | L3 - Link/drop action business logic |
| `Sources/MarkdownPreview/AppState.swift` | L4 - Application state management |
| `Sources/MarkdownPreview/AppWindowManager.swift` | L4 - Window lifecycle |
| `Sources/MarkdownPreview/ContentView.swift` | L4 - Main UI composition |
