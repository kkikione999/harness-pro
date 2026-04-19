import MarkdownUI
import SwiftUI

struct MarkdownPreviewView: View {
    let markdown: String
    let baseURL: URL?
    let onOpenLink: (URL) -> Void
    private let contentMaxWidth: CGFloat = 880

    var body: some View {
        ScrollView {
            HStack {
                Markdown(markdown, baseURL: baseURL, imageBaseURL: baseURL)
                    .markdownTheme(.gitHub)
                    .frame(maxWidth: contentMaxWidth, alignment: .leading)
                    .textSelection(.enabled)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .environment(
            \.openURL,
            OpenURLAction { url in
                onOpenLink(url)
                return .handled
            }
        )
    }
}
