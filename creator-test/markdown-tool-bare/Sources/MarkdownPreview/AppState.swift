import AppKit
import Foundation

// MARK: - AppStateProtocol

@MainActor
protocol AppStateProtocol: ObservableObject {
    associatedtype Document: Identifiable
    var id: UUID { get }
    var document: Document? { get }
    var errorMessage: String? { get set }
    var windowTitle: String { get }
    var renderMode: MarkdownRenderMode { get set }
    func reload()
    func open(url: URL)
    func save(text: String)
}

// MARK: - AppState

@MainActor
final class AppState: ObservableObject {
    private struct FileSignature: Equatable {
        let modificationDate: Date?
        let fileSize: Int?
    }

    // Class wrapper to enable identity comparison for testing
    private final class TaskBox {
        var task: Task<Void, Never>?
    }

    struct Document: Identifiable {
        let id = UUID()
        let url: URL
        var rawText: String
    }

    static let supportEmail = ProcessInfo.processInfo.environment["SUPPORT_EMAIL"]

    @Published private(set) var document: Document?
    @Published var errorMessage: String?
    @Published private(set) var windowTitle = "Markdown Preview"
    @Published var renderMode: MarkdownRenderMode = .rendered

    let watchEnabled: Bool
    private let filePollInterval: Duration
    private var filePollingTask: TaskBox?
    private let fileWatcher: FileWatcher
    private var monitoredSignature: FileSignature?
    private var monitoredURL: URL?

    init(initialURL: URL? = nil, pollInterval: Duration = .milliseconds(700), watchEnabled: Bool = false) {
        self.filePollInterval = pollInterval
        self.watchEnabled = watchEnabled
        self.fileWatcher = FileWatcher()
        if let initialURL {
            open(url: initialURL)
        }
    }

    func reload() {
        guard let currentURL = document?.url else {
            return
        }
        load(url: currentURL, restartMonitoring: false)
    }

    func open(url: URL) {
        load(url: url, restartMonitoring: true)
    }

    func save(text: String) {
        guard let url = document?.url else { return }
        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
            document?.rawText = text
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    deinit {
        // Task cancellation happens via stopMonitoring() which is called when document changes
        // or when the window closes. Here we just let the task be deallocated naturally.
    }

    private func load(url: URL, restartMonitoring: Bool) {
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            document = Document(url: url, rawText: content)
            errorMessage = nil
            windowTitle = url.lastPathComponent
            monitoredSignature = fileSignature(for: url)
            if restartMonitoring || monitoredURL != url {
                startMonitoring(url: url)
            }
        } catch {
            errorMessage = error.localizedDescription
            monitoredSignature = fileSignature(for: url)
            if let document {
                windowTitle = document.url.lastPathComponent
            } else {
                windowTitle = "Markdown Preview"
            }
        }
    }

    private func startMonitoring(url: URL) {
        stopMonitoring()
        monitoredURL = url
        monitoredSignature = fileSignature(for: url)

        if watchEnabled {
            fileWatcher.startWatching(url: url, delegate: self)
        } else {
            let box = TaskBox()
            box.task = Task { [weak self] in
                while true {
                    do {
                        try await Task.sleep(for: self?.filePollInterval ?? .seconds(1))
                    } catch {
                        break
                    }

                    if Task.isCancelled {
                        break
                    }

                    await MainActor.run {
                        self?.pollForExternalChanges(expectedURL: url)
                    }
                }
            }
            filePollingTask = box
        }
    }

    private func stopMonitoring() {
        filePollingTask?.task?.cancel()
        filePollingTask = nil
        fileWatcher.stopWatching()
        monitoredURL = nil
        monitoredSignature = nil
    }

    private func pollForExternalChanges(expectedURL url: URL) {
        guard monitoredURL == url else {
            return
        }

        let latestSignature = fileSignature(for: url)
        guard latestSignature != monitoredSignature else {
            return
        }

        monitoredSignature = latestSignature
        load(url: url, restartMonitoring: false)
    }

    private func fileSignature(for url: URL) -> FileSignature? {
        guard
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        else {
            return nil
        }

        let signature = FileSignature(modificationDate: values.contentModificationDate, fileSize: values.fileSize)
        if signature.modificationDate == nil, signature.fileSize == nil {
            return nil
        }

        return signature
    }
}

// MARK: - FileWatcherDelegate Conformance

extension AppState: FileWatcherDelegate {
    func fileWatcherDidDetectChange(_ watcher: FileWatcher) {
        guard let url = monitoredURL else { return }
        load(url: url, restartMonitoring: false)
    }
}

// MARK: - AppStateProtocol Conformance

extension AppState: AppStateProtocol {
    var id: UUID { UUID() }
}
