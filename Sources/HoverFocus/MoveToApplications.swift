import Cocoa

enum MoveToApplications {
    /// Offers to copy the app into /Applications and relaunch it from there.
    /// Returns true if a relaunch is under way and this instance should stop. The original is left untouched.
    static func offerIfNeeded() -> Bool {
        let src = Bundle.main.bundleURL
        let dirs = ["/Applications", NSHomeDirectory() + "/Applications"]
        guard !dirs.contains(where: { src.path.hasPrefix($0 + "/") }) else { return false }

        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Move HoverFocus to the Applications folder?"
        alert.informativeText = "HoverFocus works best from your Applications folder, and Launch at Login needs it to stay put."
        alert.icon = NSApp.applicationIconImage
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        let dst = URL(fileURLWithPath: "/Applications/HoverFocus.app")
        do {
            for other in NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            where other != NSRunningApplication.current { other.terminate() }
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.trashItem(at: dst, resultingItemURL: nil)
            }
            try FileManager.default.copyItem(at: src, to: dst)
            NSWorkspace.shared.openApplication(at: dst, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
            return true
        } catch {
            let fail = NSAlert()
            fail.messageText = "Couldn't move HoverFocus"
            fail.informativeText = error.localizedDescription
            fail.runModal()
            return false
        }
    }
}
