import Foundation

enum LinkOpenDecision: Equatable {
    case ignore
    case openMarkdownFile(URL)
    case openExternally(URL)
}

enum LinkHandling {
    static func decide(url: URL, baseURL: URL?) -> LinkOpenDecision {
        // MarkdownUI resolves fragment-only links (e.g. `#section`) relative to the Markdown baseURL (directory),
        // producing a file URL to that directory with a fragment. We don't support in-document scrolling, so we
        // ignore these to avoid opening Finder unexpectedly.
        if shouldIgnoreInDocumentAnchor(url: url, baseURL: baseURL) {
            return .ignore
        }

        if url.isFileURL, MarkdownFileType.isMarkdownFile(url: url) {
            return .openMarkdownFile(url.removingFragmentAndQuery())
        }

        return .openExternally(url.removingFragmentAndQuery())
    }

    private static func shouldIgnoreInDocumentAnchor(url: URL, baseURL: URL?) -> Bool {
        guard let fragment = url.fragment, !fragment.isEmpty else {
            return false
        }

        // Direct fragment-only URL.
        if url.scheme == nil, url.path.isEmpty, url.host == nil {
            return true
        }

        // Fragment resolved relative to baseURL directory.
        guard let baseURL, url.isFileURL else {
            return false
        }

        return url.standardizedFileURL.path == baseURL.standardizedFileURL.path
    }
}

private extension URL {
    func removingFragmentAndQuery() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: true) else {
            return self
        }
        components.fragment = nil
        components.query = nil
        return components.url ?? self
    }
}
