import XCTest
@testable import MarkdownPreview

@MainActor
final class FileWatcherTests: XCTestCase {
    func testStopWatchingClearsState() {
        let watcher = FileWatcher()
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("test.md")
        try? "content".write(to: fileURL, atomically: true, encoding: .utf8)

        class MockDelegate: FileWatcherDelegate {
            var changeCount = 0
            func fileWatcherDidDetectChange(_ watcher: FileWatcher) {
                changeCount += 1
            }
        }

        let delegate = MockDelegate()
        watcher.startWatching(url: fileURL, delegate: delegate)
        watcher.stopWatching()

        // After stopWatching, modifying the file should NOT trigger the delegate
        try? "modified".write(to: fileURL, atomically: true, encoding: .utf8)

        let expectation = expectation(description: "wait for potential callback")
        expectation.isInverted = true
        waitForExpectations(timeout: 0.5)

        XCTAssertEqual(delegate.changeCount, 0)
    }

    func testDetectsFileChange() async throws {
        let watcher = FileWatcher()
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        let fileURL = tempDirectory.appendingPathComponent("watch-test.md")
        try "initial content".write(to: fileURL, atomically: true, encoding: .utf8)

        class MockDelegate: FileWatcherDelegate {
            let expectation: XCTestExpectation
            init(expectation: XCTestExpectation) {
                self.expectation = expectation
            }
            func fileWatcherDidDetectChange(_ watcher: FileWatcher) {
                expectation.fulfill()
            }
        }

        let expectation = expectation(description: "File change detected")
        let delegate = MockDelegate(expectation: expectation)
        watcher.startWatching(url: fileURL, delegate: delegate)

        // Small delay to ensure watcher is active
        try await Task.sleep(for: .milliseconds(200))

        try "updated content".write(to: fileURL, atomically: true, encoding: .utf8)

        await fulfillment(of: [expectation], timeout: 3.0)

        watcher.stopWatching()
    }
}
