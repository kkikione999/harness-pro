import Dispatch
import Foundation

@MainActor
protocol FileWatcherDelegate: AnyObject {
    func fileWatcherDidDetectChange(_ watcher: FileWatcher)
}

@MainActor
final class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var watchedURL: URL?
    private var lastModificationDate: Date?
    private weak var delegate: (any FileWatcherDelegate)?

    func startWatching(url: URL, delegate: any FileWatcherDelegate) {
        stopWatching()
        self.delegate = delegate
        watchedURL = url
        lastModificationDate = modificationDate(for: url)

        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            self?.handleFileChangeEvent()
        }

        source.setCancelHandler {
            close(descriptor)
        }

        self.source = source
        source.resume()
    }

    func stopWatching() {
        source?.cancel()
        source = nil
        watchedURL = nil
        lastModificationDate = nil
        delegate = nil
    }

    private func handleFileChangeEvent() {
        guard let url = watchedURL else { return }

        let currentDate = modificationDate(for: url)
        guard currentDate != lastModificationDate else { return }

        lastModificationDate = currentDate
        delegate?.fileWatcherDidDetectChange(self)
    }

    private func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    deinit {
        source?.cancel()
    }
}
