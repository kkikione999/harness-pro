# Workflow Summary: Add --watch CLI Flag

## Task

Add a new CLI flag `--watch` that watches the markdown file for changes and auto-refreshes the preview. Requires changes to argument parsing, a new file watcher module, and integration with existing preview refresh logic.

## Steps Followed

### 1. Codebase Exploration

Read all 11 source files and 3 test files in the project to understand the architecture:

- **MarkdownPreviewApp.swift** - SwiftUI app entry point with menu commands
- **AppDelegate.swift** - Handles file opening, app lifecycle
- **AppState.swift** - Core state management with file polling (700ms interval) for external changes
- **AppWindowManager.swift** - Window management, AppStateFactory pattern
- **ContentView.swift** - Main UI with render mode picker, reload button
- Supporting files: MarkdownFileType, MarkdownInteractions, LinkHandling, MarkdownRenderMode, MarkdownPreviewView, ReadOnlyTextView

### 2. Architecture Analysis

Key findings:
- The app already has file change detection via polling (`AppState.startMonitoring` uses `Task.sleep` + `pollForExternalChanges`)
- No CLI argument parsing existed -- the app is a GUI app launched via Finder or `open` command
- The `AppStateFactory` protocol provides a clean seam for dependency injection
- `AppState` is well-structured with clear separation between loading, monitoring, and polling

### 3. Design Decisions

- **CommandLineArguments.swift** -- Simple struct with static `parse()` method. Handles `--watch` flag and positional file path argument. Order-independent (flag can come before or after file path).
- **FileWatcher.swift** -- Uses `DispatchSource.makeFileSystemObjectSource` for efficient kernel-level file change detection (vs. the existing polling approach). Watches for write, extend, delete, rename, and attrib events. Tracks modification date to deduplicate redundant notifications.
- **AppState.swift changes** -- Added `watchEnabled` property. When true, `startMonitoring` delegates to `FileWatcher` instead of creating a polling task. `stopMonitoring` cleans up both paths. `AppState` conforms to `FileWatcherDelegate` to receive change notifications.
- **AppDelegate.swift changes** -- Parses CLI arguments at launch. If `--watch` and a file path are both provided, immediately opens that file with watch mode enabled. Persists CLI args so subsequent file opens via `openFiles` also respect the watch flag.
- **AppWindowManager.swift changes** -- Added `watchEnabled` parameter to `openWindow()` and `AppStateFactory.makeAppState()`.

### 4. Implementation

Created 2 new files:
- `/Users/josh_folder/harness-simple/creator-test/markdown-tool-bare/Sources/MarkdownPreview/CommandLineArguments.swift`
- `/Users/josh_folder/harness-simple/creator-test/markdown-tool-bare/Sources/MarkdownPreview/FileWatcher.swift`

Modified 3 existing files:
- `/Users/josh_folder/harness-simple/creator-test/markdown-tool-bare/Sources/MarkdownPreview/AppState.swift`
- `/Users/josh_folder/harness-simple/creator-test/markdown-tool-bare/Sources/MarkdownPreview/AppDelegate.swift`
- `/Users/josh_folder/harness-simple/creator-test/markdown-tool-bare/Sources/MarkdownPreview/AppWindowManager.swift`

Created 2 test files:
- `/Users/josh_folder/harness-simple/creator-test/markdown-tool-bare/Tests/MarkdownPreviewTests/CommandLineArgumentsTests.swift` (6 tests)
- `/Users/josh_folder/harness-simple/creator-test/markdown-tool-bare/Tests/MarkdownPreviewTests/FileWatcherTests.swift` (2 tests)

### 5. Verification

- `swift build` succeeded with no errors
- `swift test` passed all 29 tests (21 existing + 8 new), 0 failures

## Completion Status

**Completed.** All changes compile and all tests pass. The `--watch` flag can be used as:

```bash
# Watch a specific file with DispatchSource-based monitoring
MarkdownPreview --watch /path/to/file.md

# Open app with watch mode enabled (for files opened later)
MarkdownPreview --watch
```
