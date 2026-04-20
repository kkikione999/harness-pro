# Architecture

## Overview

MarkdownPreview is a minimal macOS app that opens and previews `.md`/`.markdown` files. It supports three rendering modes (Preview, Source, Split) and auto-refreshes when files change externally.

## Layer Diagram

```
┌─────────────────────────────────────────────────────────┐
│  Layer 4: UI                                            │
│  MarkdownPreviewApp, AppDelegate, ContentView,          │
│  AppWindowManager, MarkdownPreviewView, ReadOnlyTextView│
│         ↑ can import                                    │
├─────────────────────────────────────────────────────────┤
│  Layer 3: Services                                      │
│  MarkdownInteractions, FileWatcher                      │
│         ↑ can import                                    │
├─────────────────────────────────────────────────────────┤
│  Layer 1: Utils                                         │
│  LinkHandling, CommandLineArguments                     │
│         ↑ can import                                    │
├─────────────────────────────────────────────────────────┤
│  Layer 0: Types                                         │
│  MarkdownFileType, MarkdownRenderMode                   │
└─────────────────────────────────────────────────────────┘
```

## Module Responsibilities

| Module | Layer | Responsibility |
|--------|-------|---------------|
| `MarkdownFileType` | L0 | UTType definitions, file extension validation |
| `MarkdownRenderMode` | L0 | Render mode enum (rendered/source/split) |
| `LinkHandling` | L1 | Decides how to handle clicked links |
| `CommandLineArguments` | L1 | Parses CLI flags (--watch, file path) |
| `MarkdownInteractions` | L3 | Coordinates drop actions and link actions |
| `FileWatcher` | L3 | Dispatch-source-based file change detection |
| `AppState` | L4 | Per-window state: document, error, monitoring |
| `AppWindowManager` | L4 | Window lifecycle, open panel, link routing |
| `ContentView` | L4 | Main view: header, content, drop handling |
| `MarkdownPreviewView` | L4 | Renders Markdown via MarkdownUI |
| `ReadOnlyTextView` | L4 | NSTextView wrapper for source display |
| `AppDelegate` | L4 | App lifecycle, file open events |
| `MarkdownPreviewApp` | L4 | SwiftUI App entry point |

## Dependency Rules

- L0 has NO internal imports
- L1 imports only L0
- L3 imports L0, L1
- L4 imports any lower layer
- External packages (MarkdownUI, SwiftUI, AppKit, Foundation) are exempt

## External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| swift-markdown-ui | 2.0.0+ | Markdown rendering in SwiftUI |
