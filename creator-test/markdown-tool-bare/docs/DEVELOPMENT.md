# Development Guide

## Build

```bash
# Debug build
swift build

# Release build
swift build -c release

# Build app bundle (creates dist/MarkdownPreview.app)
./scripts/build_app.sh
```

## Test

```bash
# Unit tests
swift test

# Smoke test (builds app, opens files, verifies windows)
./scripts/test_smoke.sh
```

## Lint

```bash
# Check layer dependencies
./scripts/lint-deps

# Check code quality (file length, print statements)
./scripts/lint-quality
```

## Validate (Full Pipeline)

```bash
python3 scripts/validate.py
```

Runs: build -> lint-deps -> lint-quality -> test -> verify

## Project Layout

```
Sources/MarkdownPreview/
├── MarkdownFileType.swift       # L0: File type definitions
├── MarkdownRenderMode.swift     # L0: Render mode enum
├── LinkHandling.swift           # L1: Link routing logic
├── CommandLineArguments.swift   # L1: CLI argument parsing
├── MarkdownInteractions.swift   # L3: Drop/link interaction coordinator
├── FileWatcher.swift            # L3: Dispatch-source file watcher
├── AppState.swift               # L4: Per-window state + file polling
├── AppWindowManager.swift       # L4: Window lifecycle controller
├── ContentView.swift            # L4: Main SwiftUI view
├── MarkdownPreviewView.swift    # L4: Markdown rendering view
├── ReadOnlyTextView.swift       # L4: Source text NSView wrapper
├── AppDelegate.swift            # L4: NSApplicationDelegate
└── MarkdownPreviewApp.swift     # L4: SwiftUI @main entry

Tests/MarkdownPreviewTests/
├── AppStateTests.swift
├── MarkdownFileTypeTests.swift
└── MarkdownInteractionsTests.swift
```

## Common Tasks

### Add a new CLI flag
1. Add parsing logic in `CommandLineArguments.swift` (L1)
2. Wire the flag into the app entry point or relevant L4 module

### Add a new interaction type
1. Define the action enum in `MarkdownInteractions.swift` (L3)
2. Implement the action logic
3. Wire into `ContentView` or `AppWindowManager` (L4)

### Add a new view mode
1. Add case to `MarkdownRenderMode` (L0)
2. Add rendering branch in `ContentView` (L4)
