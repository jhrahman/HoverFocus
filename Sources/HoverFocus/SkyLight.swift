import Foundation
import ApplicationServices

/// Focus-without-raise through the WindowServer's private SkyLight calls — the same technique AutoRaise and
/// yabai use. macOS has no public API that gives a window focus while leaving the stacking order alone.
/// Symbols are looked up at runtime: if a future macOS removes them, `isAvailable` is false and HoverFocus
/// falls back to the public raise-and-focus path instead of crashing.
enum SkyLight {
    private typealias SetFrontFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UInt32, UInt32) -> Int32
    private typealias PostEventFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> Int32
    private typealias GetPSNFn = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias GetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private static let skyLight = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
    private static let any = dlopen("/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices", RTLD_LAZY)

    private static func load<T>(_ handle: UnsafeMutableRawPointer?, _ name: String, as: T.Type) -> T? {
        guard let handle, let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    private static let setFront = load(skyLight, "_SLPSSetFrontProcessWithOptions", as: SetFrontFn.self)
    private static let postEvent = load(skyLight, "SLPSPostEventRecordTo", as: PostEventFn.self)
    private static let getPSN = load(any, "GetProcessForPID", as: GetPSNFn.self)
    private static let getWindow = load(any, "_AXUIElementGetWindow", as: GetWindowFn.self)

    static var isAvailable: Bool { setFront != nil && postEvent != nil && getPSN != nil }

    /// The CGWindowID behind an AX window element.
    static func windowID(of element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        guard let getWindow, getWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    /// Makes `windowID` the key window of `pid` and that app the active one, without reordering any window.
    /// `currentWindowID` is the app's current key window when the switch is between windows of the same app.
    @discardableResult
    /// With `makeKey` false the app is only activated; used for apps that raise their window when made key.
    static func focusWithoutRaise(pid: pid_t, windowID: CGWindowID, currentWindowID: CGWindowID?, makeKey: Bool = true) -> Bool {
        guard let setFront, let postEvent, let getPSN else { return false }
        var psn = ProcessSerialNumber()
        guard getPSN(pid, &psn) == noErr else { return false }

        if makeKey, let current = currentWindowID, current != windowID {
            // Same app: tell it the old key window lost focus and the new one gained it.
            var resign = record(windowID: current, type: 0x0d); resign[0x8a] = 0x02
            var become = record(windowID: windowID, type: 0x0d); become[0x8a] = 0x01
            _ = postEvent(&psn, &resign)
            // Apps like Chrome ignore the switch if both events arrive at once (yabai uses the same delay).
            usleep(10_000)
            _ = postEvent(&psn, &become)
        }
        let kCPSUserGenerated: UInt32 = 0x200
        guard setFront(&psn, windowID, kCPSUserGenerated) == 0 else { return false }
        guard makeKey else { return true }

        // Make it key: a synthetic "mouse down/up" record the WindowServer uses for key-window changes.
        var down = record(windowID: windowID, type: 0x01); down.replaceSubrange(0x20..<0x30, with: repeatElement(0xff, count: 0x10))
        var up = record(windowID: windowID, type: 0x02); up.replaceSubrange(0x20..<0x30, with: repeatElement(0xff, count: 0x10))
        down[0x3a] = 0x10; up[0x3a] = 0x10
        _ = postEvent(&psn, &down)
        _ = postEvent(&psn, &up)
        return true
    }

    private static func record(windowID: CGWindowID, type: UInt8) -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: 0xf8)
        bytes[0x04] = 0xf8
        bytes[0x08] = type
        withUnsafeBytes(of: windowID.littleEndian) { bytes.replaceSubrange(0x3c..<0x40, with: $0) }
        return bytes
    }
}
