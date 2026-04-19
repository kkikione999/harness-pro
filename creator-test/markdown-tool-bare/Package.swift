// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "MarkdownPreview",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MarkdownPreview",
            targets: ["MarkdownPreview"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "MarkdownPreview",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/MarkdownPreview"
        ),
        .testTarget(
            name: "MarkdownPreviewTests",
            dependencies: ["MarkdownPreview"],
            path: "Tests/MarkdownPreviewTests"
        )
    ]
)
