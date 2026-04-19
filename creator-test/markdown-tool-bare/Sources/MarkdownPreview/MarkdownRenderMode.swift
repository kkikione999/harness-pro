import Foundation

enum MarkdownRenderMode: String, CaseIterable, Identifiable {
    case rendered
    case source
    case split

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rendered:
            "Preview"
        case .source:
            "Source"
        case .split:
            "Split"
        }
    }
}
