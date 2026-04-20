import Foundation

struct CommandLineArguments: Sendable {
    let watchEnabled: Bool
    let filePath: String?

    static func parse(_ arguments: [String] = CommandLine.arguments) -> CommandLineArguments {
        var watchEnabled = false
        var filePath: String?

        let args = arguments.dropFirst()

        var index = args.startIndex
        while index < args.endIndex {
            let arg = args[index]

            if arg == "--watch" {
                watchEnabled = true
            } else if !arg.hasPrefix("-") {
                filePath = arg
            }

            index = args.index(after: index)
        }

        return CommandLineArguments(watchEnabled: watchEnabled, filePath: filePath)
    }
}
