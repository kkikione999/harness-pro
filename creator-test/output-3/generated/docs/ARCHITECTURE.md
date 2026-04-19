# Architecture - MarkdownPreview

## Layer Diagram

```
┌─────────────────────────────────────────────────────────────┐
│  L4: Interface                                             │
│  ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐ │
│  │ MarkdownPreviewApp│ │  AppDelegate    │ │AppWindowMgr │ │
│  │    (@main)       │ │                 │ │@MainActor   │ │
│  └─────────────────┘ └─────────────────┘ └──────────────┘ │
│  ┌─────────────────┐                                       │
│  │  ContentView    │ ← @ObservedObject, SwiftUI View       │
│  │MarkdownPreview  │ ← MarkdownUI rendering                │
│  └─────────────────┘                                       │
├─────────────────────────────────────────────────────────────┤
│  L3: Services                                              │
│  ┌─────────────────┐ ┌─────────────────────────────────┐  │
│  │    AppState     │ │     MarkdownInteractions         │  │
│  │ @MainActor      │ │ (LinkAction, DropAction enums)  │  │
│  │ File monitoring │ │                                 │  │
│  └─────────────────┘ └─────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│  L2: Config                                                │
│  (none - all config is inline or in Package.swift)         │
├─────────────────────────────────────────────────────────────┤
│  L1: Utils                                                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         ReadOnlyTextView (NSViewRepresentable)     │   │
│  │         - NSTextView wrapper for source mode        │   │
│  └─────────────────────────────────────────────────────┘   │
├─────────────────────────────────────────────────────────────┤
│  L0: Types                                                 │
│  ┌─────────────────┐ ┌─────────────────┐ ┌──────────────┐  │
│  │ MarkdownFileType│ │MarkdownRenderMode│ │LinkHandling  │  │
│  │ UTType, ext     │ │ enum (3 modes)  │ │LinkOpenDecisn│  │
│  └─────────────────┘ └─────────────────┘ └──────────────┘  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │        MarkdownLinkAction, MarkdownDropAction       │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

## Package Responsibilities

### L0: Types (no imports from other project code)
- **MarkdownFileType**: File extension validation, UTType registration
- **MarkdownRenderMode**: 3-case enum (rendered/source/split)
- **LinkHandling**: URL decision logic, fragment-only link detection
- **MarkdownLinkAction**: Link action enum (ignore/openPreview/openExternal)
- **MarkdownDropAction**: Drop action enum (ignore/currentWindow/newWindows)

### L1: Utils
- **ReadOnlyTextView**: NSViewRepresentable wrapping NSTextView for source mode editing

### L3: Services
- **AppState**: Document state, file polling, @MainActor ObservableObject
- **MarkdownInteractions**: Coordinates LinkHandling with AppWindowManager

### L4: Interface
- **MarkdownPreviewApp**: @main entry point, Scene configuration
- **AppDelegate**: NSApplicationDelegate, handles file open events
- **AppWindowManager**: Window lifecycle, @MainActor singleton
- **ContentView**: Main SwiftUI view with header + content split
- **MarkdownPreviewView**: MarkdownUI ScrollView wrapper

## Dependency Rules
1. **L0 has NO dependencies** on other project code
2. **L1 imports L0** types only
3. **L3 imports L0 and L1**
4. **L4 imports L0, L1, and L3**
5. **No reverse dependencies** - L3 cannot import L4

## @MainActor Rules
Only L4 files MAY use @MainActor:
- `AppState` (L3) - @MainActor because it holds @Published UI state
- `AppWindowManager` (L4) - @MainActor required for NSWindowController
- `PreviewWindowController` (L4) - NSWindowDelegate, must run on MainActor

## File Statistics
| File | Lines | Layer |
|------|-------|-------|
| AppState.swift | 138 | L3 |
| AppWindowManager.swift | 135 | L4 |
| ContentView.swift | 147 | L4 |
| MarkdownPreviewView.swift | 32 | L4 |
| MarkdownFileType.swift | 26 | L0 |
| MarkdownRenderMode.swift | 20 | L0 |
| MarkdownInteractions.swift | 42 | L3 |
| LinkHandling.swift | 53 | L0 |
| ReadOnlyTextView.swift | 93 | L1 |
| AppDelegate.swift | 40 | L4 |
| MarkdownPreviewApp.swift | 27 | L4 |
