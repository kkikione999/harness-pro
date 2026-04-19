# MarkdownPreview Architecture

## Project Overview
MarkdownPreview is a minimal macOS application that previews Markdown files with support for preview, source, and split rendering modes. It uses the swift-markdown-ui package for Markdown rendering.

## Layer Diagram
```
┌─────────────────────────────────────────────────────────────┐
│  L4: Interface (UI, App Lifecycle)                         │
│    AppState, AppDelegate, AppWindowManager, Views           │
│    Imports: SwiftUI, AppKit, Combine                       │
├─────────────────────────────────────────────────────────────┤
│  L3: Services (Business Logic)                             │
│    MarkdownInteractions - link/drop action decisions        │
│    Imports: Foundation, L0, L1                             │
├─────────────────────────────────────────────────────────────┤
│  L1: Utils (General Purpose Helpers)                       │
│    LinkHandling - URL decision logic                        │
│    Imports: Foundation, L0                                  │
├─────────────────────────────────────────────────────────────┤
│  L0: Types (Pure Type Definitions)                         │
│    MarkdownFileType, MarkdownRenderMode                     │
│    No internal imports allowed                              │
└─────────────────────────────────────────────────────────────┘
```

## Key Packages and Responsibilities

| File | Layer | Responsibility |
|------|-------|----------------|
| `MarkdownFileType.swift` | L0 | UTType definitions, markdown file detection |
| `MarkdownRenderMode.swift` | L0 | Render mode enum (preview/source/split) |
| `LinkHandling.swift` | L1 | Decide if URL opens in app or externally |
| `MarkdownInteractions.swift` | L3 | Link and drop action business logic |
| `AppState.swift` | L4 | Observable state, file monitoring, document management |
| `AppDelegate.swift` | L4 | App lifecycle, file open handlers |
| `AppWindowManager.swift` | L4 | Window creation and coordination |
| `MarkdownPreviewView.swift` | L4 | Markdown rendering with MarkdownUI |
| `ContentView.swift` | L4 | Main UI composition, mode picker, drag-drop |
| `ReadOnlyTextView.swift` | L4 | Source view text editor wrapper |

## Dependency Rules

1. **Higher layers can import lower layers; lower layers CANNOT import higher layers**
2. L0 (Types) - No internal imports allowed
3. L1 (Utils) - Can import L0 only
4. L2 (Config) - Can import L0, L1 (not used)
5. L3 (Services) - Can import L0, L1, L2
6. L4+ (Interface) - Can import any lower layer

## External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| swift-markdown-ui | 2.0.0+ | Markdown rendering |

## Layer Violation Examples

If a file in L3 (MarkdownInteractions) imports L4 (AppWindowManager), this is a violation because lower layers cannot import higher layers. Run `scripts/lint-deps` to check.
