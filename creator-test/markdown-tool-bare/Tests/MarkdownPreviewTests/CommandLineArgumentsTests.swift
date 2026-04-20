import XCTest
@testable import MarkdownPreview

final class CommandLineArgumentsTests: XCTestCase {
    func testNoArgumentsDefaultsToDisabled() {
        let args = CommandLineArguments.parse(["MarkdownPreview"])
        XCTAssertFalse(args.watchEnabled)
        XCTAssertNil(args.filePath)
    }

    func testWatchFlagEnablesWatchMode() {
        let args = CommandLineArguments.parse(["MarkdownPreview", "--watch"])
        XCTAssertTrue(args.watchEnabled)
        XCTAssertNil(args.filePath)
    }

    func testWatchWithFilePath() {
        let args = CommandLineArguments.parse(["MarkdownPreview", "--watch", "/path/to/file.md"])
        XCTAssertTrue(args.watchEnabled)
        XCTAssertEqual(args.filePath, "/path/to/file.md")
    }

    func testFilePathWithoutWatchFlag() {
        let args = CommandLineArguments.parse(["MarkdownPreview", "/path/to/file.md"])
        XCTAssertFalse(args.watchEnabled)
        XCTAssertEqual(args.filePath, "/path/to/file.md")
    }

    func testWatchFlagAfterFilePath() {
        let args = CommandLineArguments.parse(["MarkdownPreview", "/path/to/file.md", "--watch"])
        XCTAssertTrue(args.watchEnabled)
        XCTAssertEqual(args.filePath, "/path/to/file.md")
    }

    func testUnknownFlagsAreIgnored() {
        let args = CommandLineArguments.parse(["MarkdownPreview", "--unknown", "/file.md"])
        XCTAssertFalse(args.watchEnabled)
        XCTAssertEqual(args.filePath, "/file.md")
    }
}
