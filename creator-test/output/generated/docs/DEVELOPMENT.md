# MarkdownPreview Development Guide

## Build Commands

### Swift Package Manager
```bash
swift build              # Build debug
swift build --configuration release  # Release build
swift test               # Run all tests
swift test --enable-code-coverage    # With coverage
```

### Application Bundle
```bash
./scripts/build_app.sh    # Build dist/MarkdownPreview.app
./scripts/test_smoke.sh  # Smoke test the app
```

### Code Quality
```bash
./scripts/lint-deps      # Check layer dependencies
./scripts/lint-quality   # Check code quality rules
python3 scripts/validate.py  # Full validation pipeline
```

## Project Layout

| Path | Description |
|------|-------------|
| `Sources/MarkdownPreview/` | Main source files |
| `Tests/MarkdownPreviewTests/` | Unit tests |
| `scripts/` | Build and utility scripts |
| `dist/` | Built application output |
| `Package.swift` | Swift package manifest |

## Source Files by Layer

### L0 - Types
- `MarkdownFileType.swift` - File type detection
- `MarkdownRenderMode.swift` - Render mode enum

### L1 - Utils
- `LinkHandling.swift` - URL link decision logic

### L3 - Services
- `MarkdownInteractions.swift` - Link and drop action business logic

### L4 - Interface
- `AppState.swift` - Document and app state management
- `AppWindowManager.swift` - Window lifecycle
- `ContentView.swift` - Main content view
- `MarkdownPreviewView.swift` - Markdown rendering view
- `ReadOnlyTextView.swift` - Source text view
- `AppDelegate.swift` - App delegate
- `MarkdownPreviewApp.swift` - App entry point

## Common Development Tasks

### Running the App
```bash
# Build and run
swift build
# Or build the app bundle
./scripts/build_app.sh
open dist/MarkdownPreview.app
```

### Testing
```bash
# Run all tests
swift test

# Run specific test
swift test --filter MarkdownFileTypeTests

# With coverage report
swift test --enable-code-coverage
```

### Adding a New Feature
1. Identify which layer it belongs to
2. Write tests first (TDD)
3. Implement in the appropriate layer
4. Run `lint-deps` to verify no layer violations
5. Run `validate.py` to verify everything works

### Debugging
```bash
# Build with debug info
swift build --configuration debug

# Run with debugging
lldb .build/debug/MarkdownPreview
```

## TODO - Infrastructure Gaps

- [ ] Add SwiftLint for style enforcement
- [ ] Add SwiftFormat for auto-formatting
- [ ] Add code coverage threshold (80%)
- [ ] Create CI/CD pipeline configuration
