import Cocoa
import ApplicationServices

/// Gives the hovered window focus. By default it uses SkyLight's focus-without-raise, so focus and stacking
/// order stay independent like Windows' "activate a window by hovering". If that isn't available, it falls back
/// to the public Accessibility path, which has to bring the window to the front.
enum WindowFocuser {
    private static let queue = DispatchQueue(label: "hoverfocus.focus", qos: .userInitiated)

    /// Apps whose windows we never steal focus from or move focus to.
    private static let protectedBundles: Set<String> = [
        "com.apple.SecurityAgent", "com.apple.loginwindow", "com.apple.UserNotificationCenter",
        "com.apple.dock", "com.apple.controlcenter", "com.apple.notificationcenterui", "com.apple.Spotlight",
        "com.apple.accessibility.universalAccessAuthWarn",
    ]

    /// Bumped on every request so a queued, now-stale request never runs after the cursor has moved on.
    private static var generation = 0
    private static let lock = NSLock()

    private static func isCurrent(_ gen: Int) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return gen == generation
    }

    /// Call when the cursor leaves the pending target, so a queued request is dropped.
    static func cancelPending() {
        lock.lock(); generation += 1; lock.unlock()
    }

    static func focus(_ target: HoverWindow) {
        lock.lock(); generation += 1; let gen = generation; lock.unlock()
        queue.async {
            // Only act if this is still the latest request and the cursor is still on that window.
            guard isCurrent(gen), AXIsProcessTrusted(), NSEvent.pressedMouseButtons == 0,
                  let loc = CGEvent(source: nil)?.location,
                  WindowDetector.window(at: loc)?.id == target.id else { return }

            let frontPID = frontmostPID()
            let front = frontPID.flatMap { NSRunningApplication(processIdentifier: $0) }
            if isProtected(front) || isProtected(NSRunningApplication(processIdentifier: target.pid)) { return }
            if let frontPID, frontPID != target.pid, hasModalWindow(pid: frontPID) { return }

            // The window that currently has focus inside the target app, if that app is already active.
            // Tracked ourselves (hover focus + clicks): Chromium/Electron apps don't report it reliably through AX.
            let known = keyWindow
            let currentKey: CGWindowID? = (frontPID == target.pid && known?.pid == target.pid) ? known?.id : nil
            if currentKey == target.id { return }

            let app = AXUIElementCreateApplication(target.pid)
            AXUIElementSetMessagingTimeout(app, 0.3)
            guard let window = axWindow(in: app, matching: target) else {
                Log.debug("no AX window for pid \(target.pid) bounds \(target.bounds)")
                return
            }

            if SkyLight.isAvailable {
                // Java apps (IntelliJ and other JetBrains IDEs…) bring their window to the front whenever it is
                // made key. They also accept the first click on an inactive window, so for them activating the
                // app is enough: no raise, and the first click still lands. Everything else gets made key.
                let raisesItself = SelfRaisingApps.contains(pid: target.pid)
                let before = WindowDetector.orderedWindows()
                let started = ProcessInfo.processInfo.systemUptime
                let ok = SkyLight.focusWithoutRaise(pid: target.pid, windowID: target.id, currentWindowID: currentKey,
                                                    makeKey: !raisesItself)
                if Settings.shared.raiseOnFocus { AXUIElementPerformAction(window, kAXRaiseAction as CFString) }
                Log.debug("focus pid \(target.pid) win \(target.id) without raise: ok=\(ok) makeKey=\(!raisesItself) previousKeyInSameApp=\(currentKey.map(String.init) ?? "none")")
                if ok {
                    keyWindow = (target.pid, target.id)
                    if !raisesItself && !Settings.shared.raiseOnFocus { watchForSelfRaise(before: before, target: target, gen: gen, started: started) }
                    return
                }
            }
            focusWithRaise(app: app, window: window, target: target, gen: gen)
            keyWindow = (target.pid, target.id)
        }
    }

    /// Learns apps that raise themselves when made key (beyond the Java apps detected up front): if a window that
    /// overlapped the target and sat above it ends up below it within a second, without a click, remember the app.
    /// The raise itself can't be undone — macOS ignores AXRaise on a background app's window.
    private static func watchForSelfRaise(before: [HoverWindow], target: HoverWindow, gen: Int, started: TimeInterval) {
        let oldIndex = Dictionary(before.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { a, _ in a })
        guard let targetOld = oldIndex[target.id] else { return }
        let coveredBefore = before.prefix(targetOld).filter { $0.pid != target.pid && $0.bounds.insetBy(dx: 1, dy: 1).intersects(target.bounds) }
        guard !coveredBefore.isEmpty else { return }
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.1)
            guard isCurrent(gen), lastClick < started else { return }
            let now = WindowDetector.orderedWindows()
            guard let targetNow = now.firstIndex(where: { $0.id == target.id }) else { return }
            let above = Set(now.prefix(targetNow).map(\.id))
            if coveredBefore.contains(where: { w in now.contains { $0.id == w.id } && !above.contains(w.id) }) {
                SelfRaisingApps.learn(pid: target.pid)
                return
            }
        }
    }

    private static var _keyWindow: (pid: pid_t, id: CGWindowID)?
    /// Best knowledge of the focused window: the last one HoverFocus focused or the user clicked.
    private static var keyWindow: (pid: pid_t, id: CGWindowID)? {
        get { lock.lock(); defer { lock.unlock() }; return _keyWindow }
        set { lock.lock(); _keyWindow = newValue; lock.unlock() }
    }

    /// Called on every mouse click (main thread): the clicked window becomes the focused one.
    static func noteClick(on window: HoverWindow?) {
        lastClick = ProcessInfo.processInfo.systemUptime
        if let window { keyWindow = (window.pid, window.id) }
    }

    /// Public-API fallback (no SkyLight): activate the app and raise the window.
    private static func focusWithRaise(app: AXUIElement, window: AXUIElement, target: HoverWindow, gen: Int) {
        AXUIElementSetAttributeValue(app, kAXFocusedWindowAttribute as CFString, window)
        AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        NSRunningApplication(processIdentifier: target.pid)?.activate(options: [])
        var activated = waitUntilFrontmost(target.pid, timeout: 0.1)
        if !activated, isCurrent(gen) {
            // Cooperative activation was refused; AXFrontmost always works but raises every window of the app.
            AXUIElementSetAttributeValue(app, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
            activated = waitUntilFrontmost(target.pid, timeout: 0.3)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        Log.debug("focus pid \(target.pid) win \(target.id) with raise: activated=\(activated)")
    }

    /// The active app's pid. NSWorkspace is updated on the main thread, so read it there.
    private static func frontmostPID() -> pid_t? {
        DispatchQueue.main.sync { NSWorkspace.shared.frontmostApplication?.processIdentifier }
    }

    private static func waitUntilFrontmost(_ pid: pid_t, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if frontmostPID() == pid { return true }
            Thread.sleep(forTimeInterval: 0.01)
        } while Date() < deadline
        return false
    }

    private static var _lastClick: TimeInterval = 0
    /// Uptime of the user's most recent mouse click (set from the main thread by HoverMonitor).
    static var lastClick: TimeInterval {
        get { lock.lock(); defer { lock.unlock() }; return _lastClick }
        set { lock.lock(); _lastClick = newValue; lock.unlock() }
    }

    private static func isProtected(_ app: NSRunningApplication?) -> Bool {
        guard let id = app?.bundleIdentifier else { return false }
        return protectedBundles.contains(id)
    }

    private static func hasModalWindow(pid: pid_t) -> Bool {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.3)
        guard let win: AXUIElement = attribute(app, kAXFocusedWindowAttribute) else { return false }
        let modal: Bool? = attribute(win, "AXModal")
        return modal == true
    }

    /// Maps a CGWindow to its AXUIElement by window ID, then by frame, falling back to a hit test.
    private static func axWindow(in app: AXUIElement, matching target: HoverWindow) -> AXUIElement? {
        let windows: [AXUIElement] = attribute(app, kAXWindowsAttribute) ?? []
        if let w = windows.first(where: { SkyLight.windowID(of: $0) == target.id }) { return w }
        for w in windows {
            guard let p = point(w, kAXPositionAttribute), let s = size(w, kAXSizeAttribute) else { continue }
            let f = CGRect(origin: p, size: s)
            if abs(f.minX - target.bounds.minX) < 3, abs(f.minY - target.bounds.minY) < 3,
               abs(f.width - target.bounds.width) < 3, abs(f.height - target.bounds.height) < 3 { return w }
        }
        var el: AXUIElement?
        let c = CGPoint(x: target.bounds.midX, y: target.bounds.midY)
        guard AXUIElementCopyElementAtPosition(app, Float(c.x), Float(c.y), &el) == .success, let el else { return nil }
        return attribute(el, kAXWindowAttribute)
    }

    private static func attribute<T>(_ el: AXUIElement, _ name: String) -> T? {
        var v: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success else { return nil }
        return v as? T
    }

    private static func point(_ el: AXUIElement, _ name: String) -> CGPoint? {
        guard let v: AXValue = attribute(el, name) else { return nil }
        var p = CGPoint.zero
        return AXValueGetValue(v, .cgPoint, &p) ? p : nil
    }

    private static func size(_ el: AXUIElement, _ name: String) -> CGSize? {
        guard let v: AXValue = attribute(el, name) else { return nil }
        var s = CGSize.zero
        return AXValueGetValue(v, .cgSize, &s) ? s : nil
    }
}
