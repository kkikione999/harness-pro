import UniformTypeIdentifiers

enum MarkdownFileType {
    static let allowedFilenameExtensions = ["md", "markdown", "mdown", "mkd", "mkdn"]

    static let allowedContentTypes: [UTType] = {
        let resolvedTypes = allowedFilenameExtensions.compactMap {
            UTType(filenameExtension: $0, conformingTo: .plainText)
        }

        if resolvedTypes.isEmpty {
            return [.plainText]
        }

        return resolvedTypes
    }()

    static func isMarkdownFile(url: URL) -> Bool {
        guard url.isFileURL else {
            return false
        }

        let pathExtension = url.pathExtension.lowercased()
        return allowedFilenameExtensions.contains(pathExtension)
    }
}
