# Development Guide - MarkdownPreview

## Build Commands

```bash
# Build debug
swift build

# Build release
swift build --configuration release

# Run executable
swift run --configuration release

# Run tests with coverage
swift test --enable-code-coverage
```

## Project Layout

```
markdown-tool-bare/
├── Package.swift                    # Swift package manifest
├── Sources/MarkdownPreview/          # Main target (executable)
├── Tests/MarkdownPreviewTests/       # Test target
└── scripts/                          # Build and utility scripts
```

## Test Execution

```bash
# Run all tests
swift test

# Run specific test
swift test --filter MarkdownFileTypeTests

# Run with code coverage
swift test --enable-code-coverage
```

## Development Workflow

1. **Write test first** (TDD)
2. **Run lint checks** before committing:
   ```bash
   scripts/lint-deps        # Check layer dependencies
   scripts/lint-quality     # Check code quality
   ```
3. **Full validation**:
   ```bash
   python3 scripts/validate.py
   ```

## Adding New Features

1. **Identify layer**: Which layer does this belong to?
2. **Check dependencies**: Can it import what's needed?
3. **Write test**: Start with a failing test
4. **Implement**: Minimal code to pass test
5. **Lint**: Run `lint-deps` and `lint-quality`
6. **Validate**: Run full `validate.py`
