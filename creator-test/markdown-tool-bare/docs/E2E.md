# E2E Verification Guide

## Current Limitation

This is a native macOS SwiftUI app. No MCP tool (Chrome DevTools, Playwright, etc.) can directly interact with its UI — those tools control web browsers, not native desktop windows.

The existing verification approach uses **scripted window probing** via macOS APIs (`CGWindowListCopyWindowInfo`). This can verify window existence and titles but cannot inspect internal view state, button labels, or rendered content.

## Existing Verification

### Smoke Test (`scripts/test_smoke.sh`)

The smoke test already verifies:
1. App bundle builds successfully
2. App launches when opening markdown files via `open -a`
3. Multiple files open in separate windows
4. Window titles match opened filenames (`first.md`, `second.md`)
5. At least 2 windows appear on screen

This test uses `CGWindowListCopyWindowInfo` via an inline Swift snippet to probe the running app's windows without UI automation.

### Verify Runner (`scripts/verify/run.py`)

Wraps the smoke test. Called by `scripts/validate.py` as the final pipeline step.

## Scaffolding Recommendations

### Option A: Add Accessibility Identifiers (Recommended)

Add an `AccessibilityIdentifiers.swift` file with constants for key UI elements. This enables:
- `accessibility` command-line tool to query the view hierarchy
- XCTest UI testing targets to find elements reliably
- Future MCP-based tools to interact with the app

**Steps:**
1. ~~The `AccessibilityIdentifiers.swift` file has been generated at `Sources/MarkdownPreview/AccessibilityIdentifiers.swift`~~ ✅ Done
2. ~~Add `.accessibilityIdentifier()` modifiers to the relevant views in `ContentView.swift`~~ ✅ Done — wired into ContentView, MarkdownPreviewView, ReadOnlyTextView
3. Extend `scripts/verify/run.py` to use `accessibility` CLI or XCTest UI tests for path-level verification

### Option B: XCTest UI Testing Target

Add a UI test target that launches the app and exercises user flows.

**Steps:**
1. Add a `MarkdownPreviewUITests` target to `Package.swift` (requires Xcode project or SwiftPM UI test support)
2. Write XCUIElement-based tests for the core user paths below
3. This is more heavyweight but gives full UI interaction coverage

## Core User Paths

These are the user-facing behaviors that E2E verification should confirm after scaffolding is in place.

### Path 1: Open File and Render
1. Launch app with a markdown file (e.g., `open -a MarkdownPreview.app test.md`)
2. Verify window appears with filename as title
3. Verify rendered markdown content is displayed (requires accessibility identifiers)
4. Verify header shows filename and full path

### Path 2: Switch Render Modes
1. With a file open, locate the segmented "Preview / Source / Split" picker
2. Click "Source" — verify raw markdown text is shown
3. Click "Split" — verify both source and rendered views appear side by side
4. Click "Preview" — verify only rendered view is shown

### Path 3: Open Multiple Files
1. Launch app with two files (e.g., `open -a MarkdownPreview.app first.md second.md`)
2. Verify two windows open
3. Verify each window shows its respective file content

### Path 4: File Change Auto-Reload
1. Open a file in the app
2. Modify the file externally (e.g., `echo "new content" >> test.md`)
3. Verify the app reloads and shows updated content
4. Verify this works in both polling mode (default) and `--watch` mode (dispatch source)

### Path 5: Drag and Drop
1. With app open and no document, drop a `.md` file onto the window
2. Verify the file opens in the current window
3. With a document already open, drop another `.md` file
4. Verify a new window opens for the dropped file

### Path 6: Link Handling
1. Open a markdown file containing `[link](other.md)` where `other.md` exists
2. Click the link in rendered view
3. Verify a new preview window opens for `other.md`
4. Open a markdown file containing `[external](https://example.com)`
5. Click the external link
6. Verify the URL opens in the default browser

### Path 7: Empty State
1. Launch app with no arguments
2. Verify empty state shows "Drop in a Markdown file" message
3. Verify "Choose Markdown File..." button is visible

## How to Verify (after scaffolding)

Once accessibility identifiers are wired into views:

1. For each task that changes UI behavior, read the relevant user path above
2. Use `accessibility` CLI tool or XCTest to exercise the steps
3. Confirm the expected outcome at each step

For now, the smoke test (`scripts/test_smoke.sh`) covers Path 3 (multiple files) partially. All other paths require scaffolding to be completed first.
