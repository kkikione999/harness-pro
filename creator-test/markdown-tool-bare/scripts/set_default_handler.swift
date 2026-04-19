#!/usr/bin/swift

import CoreServices
import Foundation
import UniformTypeIdentifiers

let arguments = CommandLine.arguments

guard arguments.count >= 2 else {
    fputs("Usage: scripts/set_default_handler.swift /path/to/MarkdownPreview.app\n", stderr)
    exit(1)
}

let appURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL
guard let bundle = Bundle(url: appURL), let bundleIdentifier = bundle.bundleIdentifier else {
    fputs("Unable to read app bundle identifier from \(appURL.path(percentEncoded: false))\n", stderr)
    exit(2)
}

let markdownExtensions = ["md", "markdown", "mdown", "mkd", "mkdn"]

let lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if FileManager.default.isExecutableFile(atPath: lsregister) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: lsregister)
    process.arguments = ["-f", appURL.path(percentEncoded: false)]

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        fputs("Warning: failed to register app bundle: \(error.localizedDescription)\n", stderr)
    }
}

let knownTypeIdentifiers = Set([
    "com.joshfolder.markdown",
    "net.daringfireball.markdown",
    "public.markdown"
] + markdownExtensions.compactMap {
    UTType(filenameExtension: $0, conformingTo: .plainText)?.identifier
})

var failures: [String] = []

for typeIdentifier in knownTypeIdentifiers {
    let status = LSSetDefaultRoleHandlerForContentType(
        typeIdentifier as CFString,
        .viewer,
        bundleIdentifier as CFString
    )

    if status != noErr {
        failures.append("\(typeIdentifier) (\(status))")
    }
}

if failures.isEmpty {
    print("Set \(bundleIdentifier) as the default app for Markdown files.")
} else {
    fputs("Failed to set some type handlers: \(failures.joined(separator: ", "))\n", stderr)
    exit(3)
}
