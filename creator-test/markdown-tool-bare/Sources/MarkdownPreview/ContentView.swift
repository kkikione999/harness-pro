import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState
    let onOpenFile: () -> Void
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .dropDestination(for: URL.self) { urls, _ in
            handleDroppedFiles(urls)
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 8]))
                    .padding(16)
                    .allowsHitTesting(false)
            }
        }
        .alert("Unable to Open File", isPresented: Binding(
            get: { appState.errorMessage != nil },
            set: { shouldPresent in
                if !shouldPresent {
                    appState.errorMessage = nil
                }
            }
        )) {
            Button("OK", role: .cancel) {
                appState.errorMessage = nil
            }
        } message: {
            VStack(alignment: .leading, spacing: 8) {
                Text(appState.errorMessage ?? "Unknown error")
                if let supportEmail = AppState.supportEmail {
                    Text("Contact: \(supportEmail)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appState.document?.url.lastPathComponent ?? "Markdown Preview")
                    .font(.title2.weight(.semibold))

                Text(appState.document?.url.path(percentEncoded: false) ?? "Open a Markdown file to preview it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Picker("Mode", selection: selectedRenderMode) {
                ForEach(MarkdownRenderMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)

            Button("Reload") {
                appState.reload()
            }
            .disabled(appState.document == nil)

            Button("Open File…") {
                onOpenFile()
            }
            .keyboardShortcut("o", modifiers: [.command])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    @ViewBuilder
    private var content: some View {
        if let document = appState.document {
            switch selectedRenderMode.wrappedValue {
            case .rendered:
                renderedView(document: document)
            case .source:
                sourceView(document: document)
            case .split:
                HSplitView {
                    sourceView(document: document)
                    renderedView(document: document)
                }
            }
        } else {
            VStack(spacing: 14) {
                Text("Drop in a Markdown file")
                    .font(.title2.weight(.semibold))

                Text("This app previews Markdown files with preview, source, and split modes.")
                    .foregroundStyle(.secondary)

                Button("Choose Markdown File…") {
                    onOpenFile()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var selectedRenderMode: Binding<MarkdownRenderMode> {
        Binding(
            get: { appState.renderMode },
            set: { appState.renderMode = $0 }
        )
    }

    private func renderedView(document: AppState.Document) -> some View {
        MarkdownPreviewView(
            markdown: document.rawText,
            baseURL: document.url.deletingLastPathComponent(),
            onOpenLink: { url in
                AppWindowManager.shared.handleLink(url: url, baseURL: document.url.deletingLastPathComponent())
            }
        )
    }

    private func sourceView(document: AppState.Document) -> some View {
        ReadOnlyTextView(text: document.rawText, isMonospaced: true) { newText in
            appState.save(text: newText)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.25))
    }

    private func handleDroppedFiles(_ urls: [URL]) -> Bool {
        switch MarkdownInteractions.dropAction(for: urls, currentDocumentURL: appState.document?.url) {
        case .ignore:
            return false
        case .openInCurrentWindow(let firstURL):
            appState.open(url: firstURL)
            return true
        case .openInNewWindows(let markdownURLs):
            AppWindowManager.shared.openWindows(with: markdownURLs)
            return true
        }
    }
}
