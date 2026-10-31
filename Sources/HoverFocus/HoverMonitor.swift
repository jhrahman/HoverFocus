import Cocoa

/// Watches the mouse and focuses the window it rests on after the configured delay.
/// Event-driven: no work happens while the mouse is idle.
final class HoverMonitor {
    private let settings = Settings.shared
    private var monitor: Any?
    private var hoveredID: CGWindowID?
    private var pending: DispatchWorkItem?
    private var trailing: DispatchWorkItem?
    private var lastEval: TimeInterval = 0
    private let minInterval: TimeInterval = 0.03

    func start() {
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            if event.type == .mouseMoved {
                self?.mouseMoved()
            } else {
                WindowFocuser.noteClick(on: CGEvent(source: nil).flatMap { WindowDetector.window(at: $0.location) })
            }
        }
    }

    func stop() {
        if let m = monitor { NSEvent.removeMonitor(m) }
        monitor = nil
        reset()
    }

    /// Forget the current hover (after sleep/wake, display changes, or being toggled).
    func reset() {
        hoveredID = nil
        pending?.cancel(); pending = nil
        trailing?.cancel(); trailing = nil
    }

    private func mouseMoved() {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastEval >= minInterval else {
            // Throttled: make sure the final resting position still gets evaluated.
            if trailing == nil {
                let item = DispatchWorkItem { [weak self] in self?.trailing = nil; self?.evaluate() }
                trailing = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
            }
            return
        }
        evaluate()
    }

    private func evaluate() {
        lastEval = ProcessInfo.processInfo.systemUptime
        guard settings.enabled, AXIsProcessTrusted(), NSEvent.pressedMouseButtons == 0,
              let loc = CGEvent(source: nil)?.location else {
            hoveredID = nil
            pending?.cancel(); pending = nil
            WindowFocuser.cancelPending()
            return
        }

        guard let target = WindowDetector.window(at: loc) else {
            hoveredID = nil
            pending?.cancel(); pending = nil
            WindowFocuser.cancelPending()
            return
        }
        guard target.id != hoveredID else { return }   // still in the same window
        Log.debug("hover \(target.id) pid \(target.pid) at \(loc)")
        hoveredID = target.id
        pending?.cancel(); pending = nil
        WindowFocuser.cancelPending()

        if settings.delay == .instant {
            WindowFocuser.focus(target)
        } else {
            let item = DispatchWorkItem { WindowFocuser.focus(target) }
            pending = item
            DispatchQueue.main.asyncAfter(deadline: .now() + settings.delay.seconds, execute: item)
        }
    }
}
