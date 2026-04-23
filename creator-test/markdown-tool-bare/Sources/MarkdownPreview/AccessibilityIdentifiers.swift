import Foundation

/// Accessibility identifiers for key UI elements.
/// Use with `.accessibilityIdentifier()` on SwiftUI views to enable
/// programmatic UI querying via XCTest UI tests or the `accessibility` CLI tool.
///
/// See docs/E2E.md for the full verification strategy.
enum AccessibilityID {
    enum ContentView {
        static let headerTitle = "content-header-title"
        static let headerPath = "content-header-path"
        static let renderModePicker = "render-mode-picker"
        static let reloadButton = "reload-button"
        static let openFileButton = "open-file-button"
        static let chooseFileButton = "choose-file-button"
        static let dropZoneLabel = "drop-zone-label"
    }

    enum MarkdownPreviewView {
        static let renderedContent = "markdown-rendered-content"
        static let copyTextContextButton = "copy-text-button"
    }

    enum SourceView {
        static let sourceText = "source-text-editor"
    }
}
