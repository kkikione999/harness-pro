import XCTest
@testable import MarkdownPreview

final class MarkdownFileTypeTests: XCTestCase {
    func testAllowedFilenameExtensionsAreStable() {
        XCTAssertEqual(
            MarkdownFileType.allowedFilenameExtensions,
            ["md", "markdown", "mdown", "mkd", "mkdn"]
        )
    }

    func testAllowedContentTypesCoverEveryFilenameExtension() {
        let identifiers = Set(MarkdownFileType.allowedContentTypes.map(\.identifier))

        for fileExtension in MarkdownFileType.allowedFilenameExtensions {
            let type = MarkdownFileType.allowedContentTypes.first {
                $0.preferredFilenameExtension == fileExtension
                    || $0.tags[.filenameExtension]?.contains(fileExtension) == true
            }

            XCTAssertNotNil(type, "Missing UTType for extension \(fileExtension)")
        }

        XCTAssertFalse(identifiers.isEmpty)
    }

    func testRecognizesLocalMarkdownFiles() {
        XCTAssertTrue(MarkdownFileType.isMarkdownFile(url: URL(fileURLWithPath: "/tmp/readme.md")))
        XCTAssertTrue(MarkdownFileType.isMarkdownFile(url: URL(fileURLWithPath: "/tmp/readme.MARKDOWN")))
        XCTAssertFalse(MarkdownFileType.isMarkdownFile(url: URL(fileURLWithPath: "/tmp/readme.txt")))
        XCTAssertFalse(MarkdownFileType.isMarkdownFile(url: URL(string: "https://example.com/readme.md")!))
    }
}
