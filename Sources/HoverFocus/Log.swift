import Foundation

/// Opt-in diagnostics: `defaults write com.hoverfocus.app debug -bool true`, then read ~/Library/Logs/HoverFocus.log.
enum Log {
    private static let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/HoverFocus.log")
    private static let queue = DispatchQueue(label: "hoverfocus.log")

    static func debug(_ message: @autoclosure () -> String) {
        guard UserDefaults.standard.bool(forKey: "debug") else { return }
        let line = "\(Date()) \(message())\n"
        queue.async {
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
            } else {
                try? line.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }
}
