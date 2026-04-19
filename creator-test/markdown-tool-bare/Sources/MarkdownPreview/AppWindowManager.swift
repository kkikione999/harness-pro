import AppKit
import Combine
import SwiftUI

// MARK: - AppStateFactory

@MainActor
protocol AppStateFactory {
    func makeAppState(initialURL: URL?) -> any AppStateProtocol
}

final class DefaultAppStateFactory: AppStateFactory {
    func makeAppState(initialURL: URL?) -> any AppStateProtocol {
        AppState(initialURL: initialURL)
    }
}

// MARK: - AppWindowManager

@MainActor
final class AppWindowManager {
    static let shared = AppWindowManager()

    private var controllers: [ObjectIdentifier: PreviewWindowController] = [:]
    private weak var activeController: PreviewWindowController?
    private let appStateFactory: AppStateFactory

    private init(factory: AppStateFactory = DefaultAppStateFactory()) {
        self.appStateFactory = factory
    }

    func openWindow(with url: URL? = nil) {
        let appState = appStateFactory.makeAppState(initialURL: url)
        let controller = PreviewWindowController(
            appState: appState,
            onOpenFile: { [weak self] in
                self?.showOpenPanel()
            },
            onClose: { [weak self] controller in
                self?.remove(controller)
            }
        )

        let identifier = ObjectIdentifier(controller)
        controllers[identifier] = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        activeController = controller
        NSApp.activate(ignoringOtherApps: true)
    }

    func openWindows(with urls: [URL]) {
        for url in urls {
            openWindow(with: url)
        }
    }

    func showOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = MarkdownFileType.allowedContentTypes
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Open"

        if panel.runModal() == .OK {
            openWindows(with: panel.urls)
        }
    }

    func reloadActiveWindow() {
        activeController?.appState.reload()
    }

    func handleLink(url: URL, baseURL: URL?) {
        switch MarkdownInteractions.linkAction(for: url, baseURL: baseURL) {
        case .ignore:
            return
        case .openMarkdownPreview(let markdownURL):
            if FileManager.default.isReadableFile(atPath: markdownURL.path) {
                openWindow(with: markdownURL)
            } else {
                activeController?.appState.errorMessage = "Unable to open linked file: \(markdownURL.lastPathComponent)"
                NSSound.beep()
            }
        case .openExternal(let externalURL):
            NSWorkspace.shared.open(externalURL)
        }
    }

    func activate(_ controller: PreviewWindowController) {
        activeController = controller
    }

    private func remove(_ controller: PreviewWindowController) {
        if activeController === controller {
            activeController = controllers.values.first { $0 !== controller }
        }
        controllers.removeValue(forKey: ObjectIdentifier(controller))
    }
}

@MainActor
final class PreviewWindowController: NSWindowController, NSWindowDelegate {
    let appState: any AppStateProtocol
    private let concreteAppState: AppState

    private var cancellables: Set<AnyCancellable> = []
    private let onClose: (PreviewWindowController) -> Void

    init(
        appState: any AppStateProtocol,
        onOpenFile: @escaping () -> Void,
        onClose: @escaping (PreviewWindowController) -> Void
    ) {
        self.appState = appState
        self.concreteAppState = appState as! AppState
        self.onClose = onClose

        let rootView = ContentView(appState: concreteAppState, onOpenFile: onOpenFile)
            .frame(minWidth: 900, minHeight: 620)
        let hostingController = NSHostingController(rootView: rootView)

        let window = NSWindow(contentViewController: hostingController)
        window.setContentSize(NSSize(width: 980, height: 700))
        window.minSize = NSSize(width: 900, height: 620)
        window.title = appState.windowTitle
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)

        window.delegate = self

        concreteAppState.$windowTitle
            .receive(on: RunLoop.main)
            .sink { [weak window] title in
                window?.title = title
            }
            .store(in: &cancellables)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func windowWillClose(_ notification: Notification) {
        onClose(self)
    }

    func windowDidBecomeMain(_ notification: Notification) {
        AppWindowManager.shared.activate(self)
    }
}
