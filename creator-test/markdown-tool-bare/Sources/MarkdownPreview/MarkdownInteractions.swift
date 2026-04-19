import Foundation

enum MarkdownLinkAction: Equatable {
    case ignore
    case openMarkdownPreview(URL)
    case openExternal(URL)
}

enum MarkdownDropAction: Equatable {
    case ignore
    case openInCurrentWindow(URL)
    case openInNewWindows([URL])
}

enum MarkdownInteractions {
    static func linkAction(for url: URL, baseURL: URL?) -> MarkdownLinkAction {
        switch LinkHandling.decide(url: url, baseURL: baseURL) {
        case .ignore:
            return .ignore
        case .openMarkdownFile(let fileURL):
            return .openMarkdownPreview(fileURL.standardizedFileURL)
        case .openExternally(let externalURL):
            return .openExternal(externalURL)
        }
    }

    static func dropAction(for urls: [URL], currentDocumentURL: URL?) -> MarkdownDropAction {
        let markdownURLs = urls
            .map(\.standardizedFileURL)
            .filter(MarkdownFileType.isMarkdownFile(url:))

        guard !markdownURLs.isEmpty else {
            return .ignore
        }

        if currentDocumentURL == nil, markdownURLs.count == 1, let firstURL = markdownURLs.first {
            return .openInCurrentWindow(firstURL)
        }

        return .openInNewWindows(markdownURLs)
    }
}
