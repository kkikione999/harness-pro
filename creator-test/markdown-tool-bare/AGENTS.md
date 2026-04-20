# MarkdownPreview Agent Guide

## Reading Path
- [Architecture](docs/ARCHITECTURE.md)
- [Development](docs/DEVELOPMENT.md)

## Build Commands
```bash
swift build                              # Debug build
swift build -c release                   # Release build
swift test                               # Run tests
./scripts/build_app.sh                   # Build app bundle
./scripts/test_smoke.sh                  # Smoke test (builds + launches app)
./scripts/lint-deps                      # Check layer dependencies
./scripts/lint-quality                   # Check code quality
python3 scripts/validate.py              # Full validation pipeline
```

## Layer Rules (Higher imports Lower, never the reverse)
```
Layer 0: MarkdownFileType, MarkdownRenderMode    # Pure types, no internal imports
Layer 1: LinkHandling, CommandLineArguments       # Utils, import only L0
Layer 3: MarkdownInteractions, FileWatcher        # Services, import L0-L1
Layer 4: AppState, AppWindowManager, ContentView  # UI, import any lower
         MarkdownPreviewView, ReadOnlyTextView
         AppDelegate, MarkdownPreviewApp
```

## Core Principles
- **Repository is the only source of truth** - Rules live in Git, not in chat
- **Coordinator never writes code** - Delegate to sub-agents for multi-file changes
- **Validate before acting** - Run lint-deps before adding cross-module imports
- **Context is expensive** - Prefer focused sub-agent prompts over giant context

## Key Conventions
- Swift 6.2, macOS 14+, strict concurrency
- Single executable target: `MarkdownPreview`
- External dependency: `swift-markdown-ui` (MarkdownUI)
- Tests use XCTest (not Swift Testing)
- File polling for external changes via AppState (700ms interval)
- Dispatch source file watching via FileWatcher (for --watch mode)
