import SwiftUI

@main
struct MarkdownPreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .appSettings) { }
            CommandGroup(after: .appInfo) {
                Button("Open Markdown File…") {
                    AppWindowManager.shared.showOpenPanel()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Reload") {
                    AppWindowManager.shared.reloadActiveWindow()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
