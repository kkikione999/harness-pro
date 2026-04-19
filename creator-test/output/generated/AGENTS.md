# MarkdownPreview Agent Guide

## Reading Path
- [Architecture](docs/ARCHITECTURE.md)
- [Development](docs/DEVELOPMENT.md)

## Build Commands
```bash
swift build        # Build the project
swift test         # Run tests
swift build --configuration release  # Release build
./scripts/build_app.sh  # Build distributable app
```

## Layer Rules
```
Layer 0: MarkdownFileType, MarkdownRenderMode (types only)
Layer 1: LinkHandling (utilities)
Layer 3: MarkdownInteractions (business logic)
Layer 4: AppState, AppWindowManager, ContentView, MarkdownPreviewView, ReadOnlyTextView, AppDelegate, MarkdownPreviewApp (interface)
```

**The One Rule**: Higher layers can import lower layers; lower CANNOT import higher.

## Coding Rules
- No hardcoded strings (use constants or LocalizedStringKey)
- Structured logging only (os.Logger)
- Max 500 lines per file
- Use let over var; struct over class by default
- Swift 6 concurrency: Sendable types, actors for shared state

## Common Tasks
```bash
# Development
swift build && swift test

# Lint
./scripts/lint-deps      # Check layer dependencies
./scripts/lint-quality   # Check code quality

# Validate
python3 scripts/validate.py

# Build app
./scripts/build_app.sh
```

## External Dependencies
- swift-markdown-ui (MarkdownUI for rendering)
- Foundation, AppKit, SwiftUI (system frameworks)
