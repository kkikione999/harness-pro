import XCTest
@testable import MarkdownPreview

final class MarkdownInteractionsTests: XCTestCase {
    func testMarkdownLinkActionOpensPreviewWindow() {
        let url = URL(fileURLWithPath: "/tmp/docs/readme.md")

        let action = MarkdownInteractions.linkAction(for: url, baseURL: URL(fileURLWithPath: "/tmp/docs"))

        XCTAssertEqual(action, .openMarkdownPreview(url.standardizedFileURL))
    }

    func testExternalLinkActionUsesSystemOpen() {
        let url = URL(string: "https://example.com/docs")!

        let action = MarkdownInteractions.linkAction(for: url, baseURL: nil)

        XCTAssertEqual(action, .openExternal(url))
    }

    func testFragmentOnlyAnchorIsIgnored() {
        let url = URL(string: "#tasks")!

        let action = MarkdownInteractions.linkAction(for: url, baseURL: URL(fileURLWithPath: "/tmp/docs"))

        XCTAssertEqual(action, .ignore)
    }

    func testAnchorResolvedToBaseDirectoryIsIgnored() {
        let baseURL = URL(fileURLWithPath: "/tmp/docs")
        let resolvedURL = URL(string: "#tasks", relativeTo: baseURL)!

        let action = MarkdownInteractions.linkAction(for: resolvedURL, baseURL: baseURL)

        XCTAssertEqual(action, .ignore)
    }

    func testMailToOpensExternally() {
        let url = URL(string: "mailto:test@example.com")!

        let action = MarkdownInteractions.linkAction(for: url, baseURL: nil)

        XCTAssertEqual(action, .openExternal(url))
    }

    func testMarkdownLinkWithFragmentOpensMarkdownFileWithoutFragment() {
        var components = URLComponents()
        components.scheme = "file"
        components.path = "/tmp/docs/readme.md"
        components.fragment = "intro"
        let withFragment = components.url!

        let action = MarkdownInteractions.linkAction(for: withFragment, baseURL: URL(fileURLWithPath: "/tmp/docs"))

        XCTAssertEqual(action, .openMarkdownPreview(URL(fileURLWithPath: "/tmp/docs/readme.md")))
    }

    func testDropActionIgnoresNonMarkdownFiles() {
        let action = MarkdownInteractions.dropAction(
            for: [URL(fileURLWithPath: "/tmp/readme.txt")],
            currentDocumentURL: nil
        )

        XCTAssertEqual(action, .ignore)
    }

    func testDropActionReusesEmptyWindowForSingleMarkdownFile() {
        let fileURL = URL(fileURLWithPath: "/tmp/new.md")

        let action = MarkdownInteractions.dropAction(
            for: [fileURL],
            currentDocumentURL: nil
        )

        XCTAssertEqual(action, .openInCurrentWindow(fileURL.standardizedFileURL))
    }

    func testDropActionOpensNewWindowsWhenCurrentWindowAlreadyHasDocument() {
        let currentURL = URL(fileURLWithPath: "/tmp/current.md")
        let droppedURL = URL(fileURLWithPath: "/tmp/next.md")

        let action = MarkdownInteractions.dropAction(
            for: [droppedURL],
            currentDocumentURL: currentURL
        )

        XCTAssertEqual(action, .openInNewWindows([droppedURL.standardizedFileURL]))
    }

    func testDropActionKeepsOnlyMarkdownFilesForMultipleDrops() {
        let firstURL = URL(fileURLWithPath: "/tmp/one.md")
        let secondURL = URL(fileURLWithPath: "/tmp/two.markdown")
        let ignoredURL = URL(fileURLWithPath: "/tmp/notes.txt")

        let action = MarkdownInteractions.dropAction(
            for: [firstURL, ignoredURL, secondURL],
            currentDocumentURL: URL(fileURLWithPath: "/tmp/existing.md")
        )

        XCTAssertEqual(
            action,
            .openInNewWindows([firstURL.standardizedFileURL, secondURL.standardizedFileURL])
        )
    }
}
