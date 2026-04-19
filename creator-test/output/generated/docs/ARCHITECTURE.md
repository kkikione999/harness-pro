# MarkdownPreview Architecture

## Project Overview

MarkdownPreview is a minimal macOS Markdown preview application that renders `.md`/`.markdown` files with support for preview, source, and split view modes.

**Language**: Swift 6.2+
**Platform**: macOS 14+
**Architecture**: Layered (L0-L4)

## Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  L4: Interface (AppKit, SwiftUI, UI)                        │
│    AppWindowManager, ContentView, MarkdownPreviewView,      │
│    ReadOnlyTextView, AppState, AppDelegate, MarkdownPreviewApp│
│         ↑ can import                                        │
├─────────────────────────────────────────────────────────────┤
│  L3: Services (Business Logic)                              │
│    MarkdownInteractions (link action, drop action)           │
│         ↑ can import                                        │
├─────────────────────────────────────────────────────────────┤
│  L2: Config (not used in this project)                      │
├─────────────────────────────────────────────────────────────┤
│  L1: Utils                                                  │
│    LinkHandling (URL decision logic)                        │
│         ↑ can import                                        │
├─────────────────────────────────────────────────────────────┤
│  L0: Types (no internal imports)                            │
│    MarkdownFileType, MarkdownRenderMode                     │
└─────────────────────────────────────────────────────────────┘
```

## Key Packages and Responsibilities

| File | Layer | Responsibility |
|------|-------|----------------|
| `MarkdownFileType.swift` | L0 | File type detection, UTType definitions |
| `MarkdownRenderMode.swift` | L0 | Enum for preview/source/split modes |
| `LinkHandling.swift` | L1 | URL link decision logic (ignore/open internally/open externally) |
| `MarkdownInteractions.swift` | L3 | Business logic for link actions and drop actions |
| `AppState.swift` | L4 | Document state, file monitoring, window title |
| `AppWindowManager.swift` | L4 | Window lifecycle, open/close management |
| `ContentView.swift` | L4 | Main SwiftUI view composition |
| `MarkdownPreviewView.swift` | L4 | MarkdownUI rendering view |
| `ReadOnlyTextView.swift` | L4 | Source view with NSTextView |
| `AppDelegate.swift` | L4 | NSApplication delegate |
| `MarkdownPreviewApp.swift` | L4 | @main app entry point |

## Dependency Rules

1. **L0 (Types)** must have NO internal imports
2. **L1 (Utils)** can only import Foundation and L0 types
3. **L3 (Services)** can import Foundation, L0, and L1
4. **L4 (Interface)** can import any lower layer and system frameworks (AppKit, SwiftUI, Combine, MarkdownUI)

## External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| swift-markdown-ui | 2.0.0+ | Markdown rendering |
| Foundation | system | Base utilities |
| AppKit | system | macOS UI framework |
| SwiftUI | system | Declarative UI |
| Combine | system | Reactive bindings |
| UniformTypeIdentifiers | system | File type identification |

## Layer Dependency Graph

```
MarkdownFileType (L0) ──> Foundation
MarkdownRenderMode (L0) ──> Foundation

LinkHandling (L1) ──> Foundation, MarkdownFileType (L0)

MarkdownInteractions (L3) ──> Foundation, LinkHandling (L1), MarkdownFileType (L0)

AppState (L4) ──> SwiftUI, MarkdownRenderMode (L0), MarkdownInteractions (L3)
AppWindowManager (L4) ──> AppKit, Combine, SwiftUI, MarkdownFileType (L0), MarkdownInteractions (L3)
ContentView (L4) ──> SwiftUI, AppState (L4), MarkdownRenderMode (L0), MarkdownInteractions (L3), AppWindowManager (L4)
MarkdownPreviewView (L4) ──> MarkdownUI, SwiftUI
ReadOnlyTextView (L4) ──> AppKit, SwiftUI
AppDelegate (L4) ──> AppKit, Foundation, AppWindowManager (L4)
MarkdownPreviewApp (L4) ──> AppKit, SwiftUI, AppWindowManager (L4)
```

## Violation Examples

**GOOD** (L4 imports L3):
```
AppWindowManager.swift (L4) imports MarkdownInteractions.swift (L3) ✓
```

**BAD** (L3 imports L4):
```
MarkdownInteractions.swift (L3) imports AppState.swift (L4) ✗
```

**BAD** (L1 imports L3):
```
LinkHandling.swift (L1) imports AppWindowManager.swift (L4) ✗
```
