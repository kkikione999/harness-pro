# MarkdownPreview Development Guide

## Build Commands

### Swift Package Build
```bash
swift build
```

### Release Build + App Bundle
```bash
./scripts/build_app.sh
```
Creates: `dist/MarkdownPreview.app`

### Tests
```bash
swift test                          # Unit tests
./scripts/test_smoke.sh             # E2E smoke test
```

### Validation Pipeline
```bash
python3 scripts/validate.py          # Full pipeline: build -> lint -> test -> verify
```

## Common Development Tasks

### Create a New Markdown File Handler
1. Add file type logic to `MarkdownFileType.swift` (L0)
2. Add link handling in `LinkHandling.swift` (L1)
3. Add business logic in `MarkdownInteractions.swift` (L3)
4. Wire up UI in appropriate view (L4)

### Add New Render Mode
1. Add case to `MarkdownRenderMode.swift` (L0)
2. Update UI in `ContentView.swift` (L4)

### Modify File Monitoring
- File monitoring logic is in `AppState.swift` (L4)
- Poll interval is configurable via `pollInterval` parameter

## Project Layout

| Path | Description |
|------|-------------|
| `Sources/MarkdownPreview/` | Main source files |
| `Tests/MarkdownPreviewTests/` | Unit tests |
| `Support/Info.plist` | App bundle Info.plist |
| `scripts/` | Build and test scripts |
| `dist/` | Built app bundle output |

## TODO: Gaps to Fill
- [ ] Add integration tests for window coordination
- [ ] Add performance tests for large Markdown files
- [ ] Consider adding L2 (config) for user preferences
