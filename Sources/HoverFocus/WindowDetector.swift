import Cocoa

struct HoverWindow {
    let id: CGWindowID
    let pid: pid_t
    let bounds: CGRect
}

enum WindowDetector {
    /// The normal app window under `point` (CG global coordinates, top-left origin), or nil when the
    /// cursor is over something HoverFocus must leave alone: the Dock, menu bar, desktop, an open
    /// menu, a popup, or our own windows. Works the same on every display.
    static func window(at point: CGPoint) -> HoverWindow? {
        let me = ProcessInfo.processInfo.processIdentifier
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        // The list is ordered front to back.
        for w in list {
            guard let pid = w[kCGWindowOwnerPID as String] as? pid_t else { continue }
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            // An open menu: moving focus now would dismiss it.
            if layer == Int(CGWindowLevelForKey(.popUpMenuWindow)) && pid != me { return nil }
            if (w[kCGWindowAlpha as String] as? Double ?? 1) < 0.05 { continue }
            guard let d = w[kCGWindowBounds as String] as? NSDictionary,
                  let b = CGRect(dictionaryRepresentation: d), b.contains(point) else { continue }
            // Full-display overlays (e.g. the Dock's invisible full-screen window) sit above every app
            // window on that display; skip them instead of treating them as "something to leave alone".
            if layer != 0 && coversADisplay(b) { continue }
            if pid == me || layer != 0 { return nil }
            return HoverWindow(id: w[kCGWindowNumber as String] as? CGWindowID ?? 0, pid: pid, bounds: b)
        }
        return nil
    }

    /// All normal app windows currently on screen, front to back.
    static func orderedWindows() -> [HoverWindow] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { w in
            guard (w[kCGWindowLayer as String] as? Int) == 0,
                  (w[kCGWindowAlpha as String] as? Double ?? 1) >= 0.05,
                  let pid = w[kCGWindowOwnerPID as String] as? pid_t,
                  let id = w[kCGWindowNumber as String] as? CGWindowID,
                  let d = w[kCGWindowBounds as String] as? NSDictionary,
                  let b = CGRect(dictionaryRepresentation: d) else { return nil }
            return HoverWindow(id: id, pid: pid, bounds: b)
        }
    }

    private static func coversADisplay(_ r: CGRect) -> Bool {
        var count: UInt32 = 0
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        CGGetActiveDisplayList(16, &ids, &count)
        return ids.prefix(Int(count)).contains { id in
            let d = CGDisplayBounds(id)
            return r.width >= d.width - 2 && r.height >= d.height - 2 && r.intersects(d)
        }
    }
}
