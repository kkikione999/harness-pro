// MARK: - AppDelegate
import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var cliArguments: CommandLineArguments?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let args = CommandLineArguments.parse()
        cliArguments = args

        if args.watchEnabled, let filePath = args.filePath {
            let url = URL(fileURLWithPath: filePath)
            Task { @MainActor in
                AppWindowManager.shared.openWindow(with: url, watchEnabled: true)
            }
        }
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let urls = filenames.map { URL(fileURLWithPath: $0) }
        let watchEnabled = cliArguments?.watchEnabled ?? false
        Task { @MainActor in
            for url in urls {
                AppWindowManager.shared.openWindow(with: url, watchEnabled: watchEnabled)
            }
        }
        sender.reply(toOpenOrPrint: .success)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            for url in urls {
                AppWindowManager.shared.openWindow(with: url)
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        AppWindowManager.shared.openWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
