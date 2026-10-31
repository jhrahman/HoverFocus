import Cocoa

/// Apps that bring their own window to the front when it's made key, so HoverFocus only activates them.
/// Java apps are recognised from their bundle; others are learned at runtime and remembered by bundle ID.
enum SelfRaisingApps {
    private static let lock = NSLock()
    private static var cache: [pid_t: Bool] = [:]
    private static let defaultsKey = "selfRaisingApps"

    static func contains(pid: pid_t) -> Bool {
        lock.lock(); defer { lock.unlock() }
        if let known = cache[pid] { return known }
        let app = NSRunningApplication(processIdentifier: pid)
        let learned = Set(UserDefaults.standard.stringArray(forKey: defaultsKey) ?? [])
        let result = app.map { isJava($0) || ($0.bundleIdentifier.map(learned.contains) ?? false) } ?? false
        cache[pid] = result
        return result
    }

    static func learn(pid: pid_t) {
        lock.lock(); defer { lock.unlock() }
        cache[pid] = true
        guard let id = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier else { return }
        var learned = UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
        if !learned.contains(id) { learned.append(id); UserDefaults.standard.set(learned, forKey: defaultsKey) }
        Log.debug("\(id) raises its window when made key; it will only be activated from now on")
    }

    private static func isJava(_ app: NSRunningApplication) -> Bool {
        if app.executableURL?.lastPathComponent == "java" { return true }
        guard let bundle = app.bundleURL else { return false }
        let fm = FileManager.default
        // Bundled Java runtimes: JetBrains (jbr), jpackage (runtime), older launchers (JVMOptions in Info.plist).
        if fm.fileExists(atPath: bundle.appendingPathComponent("Contents/jbr").path) { return true }
        if fm.fileExists(atPath: bundle.appendingPathComponent("Contents/runtime/Contents/Home").path) { return true }
        let info = Bundle(url: bundle)?.infoDictionary
        return info?["JVMOptions"] != nil || info?["JavaX"] != nil
    }
}
