import XCTest
@testable import MarkdownPreview

@MainActor
final class AppStateTests: XCTestCase {
    func testOpenSetsDocumentAndWindowTitle() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("sample.md")
        try "# Title\n\nHello".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.open(url: fileURL)

        XCTAssertEqual(state.document?.url, fileURL)
        XCTAssertEqual(state.document?.rawText, "# Title\n\nHello")
        XCTAssertEqual(state.windowTitle, "sample.md")
        XCTAssertNil(state.errorMessage)
    }

    func testReloadReadsLatestFileContents() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("reload.md")
        try "old".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.open(url: fileURL)
        try "new".write(to: fileURL, atomically: true, encoding: .utf8)
        state.reload()

        XCTAssertEqual(state.document?.rawText, "new")
        XCTAssertNil(state.errorMessage)
    }

    func testAutoReloadsWhenOpenedFileChangesExternally() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("watch.md")
        try "before".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.open(url: fileURL)

        try "after".write(to: fileURL, atomically: true, encoding: .utf8)

        for _ in 0..<30 {
            if state.document?.rawText == "after" {
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        XCTAssertEqual(state.document?.rawText, "after")
        XCTAssertNil(state.errorMessage)
    }

    func testReloadWithoutDocumentIsNoOp() {
        let state = AppState()
        state.reload()

        XCTAssertNil(state.document)
        XCTAssertNil(state.errorMessage)
        XCTAssertEqual(state.windowTitle, "Markdown Preview")
    }

    func testOpenFailureSetsError() {
        let state = AppState()
        let missingURL = URL(fileURLWithPath: "/tmp/\(UUID().uuidString)/missing.md")

        state.open(url: missingURL)

        XCTAssertNil(state.document)
        XCTAssertNotNil(state.errorMessage)
        XCTAssertEqual(state.windowTitle, "Markdown Preview")
    }

    func testOpenFailurePreservesExistingDocument() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("stable.md")
        try "stable".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.open(url: fileURL)
        let missingURL = tempDirectory.appendingPathComponent("missing.md")

        state.open(url: missingURL)

        XCTAssertEqual(state.document?.url, fileURL)
        XCTAssertEqual(state.document?.rawText, "stable")
        XCTAssertEqual(state.windowTitle, "stable.md")
        XCTAssertNotNil(state.errorMessage)
    }

    func testSaveUpdatesDocumentWithoutReloading() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("save.md")
        try "original".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.open(url: fileURL)

        state.save(text: "modified")

        XCTAssertEqual(state.document?.rawText, "modified")
    }

    func testSaveDoesNotRestartFileMonitoring() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("monitor.md")
        try "initial".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = AppState()
        state.open(url: fileURL)

        // Get the current file monitoring task box via AnyObject for identity comparison
        let firstBox = Mirror(reflecting: state).children.first { $0.label == "filePollingTask" }?.value as AnyObject?

        state.save(text: "modified")

        // The polling task should NOT have been restarted
        let secondBox = Mirror(reflecting: state).children.first { $0.label == "filePollingTask" }?.value as AnyObject?

        XCTAssertTrue(firstBox === secondBox, "filePollingTask should not be recreated on save")
    }
}
