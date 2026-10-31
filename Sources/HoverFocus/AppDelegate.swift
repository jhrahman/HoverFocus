import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private let permission = AccessibilityPermission.shared
    private let monitor = HoverMonitor()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let enableItem = NSMenuItem(title: "Enable HoverFocus", action: #selector(toggleEnabled), keyEquivalent: "")
    private var window: NSWindow?
    private var bag = Set<AnyCancellable>()
    private var launchedAtLogin = false

    func applicationWillFinishLaunching(_ notification: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        launchedAtLogin = event?.paramDescriptor(forKeyword: AEKeyword(keyAEPropData))?.enumCodeValue
            == OSType(keyAELaunchedAsLogInItem)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if MoveToApplications.offerIfNeeded() { return }

        buildStatusItem()
        settings.$enabled.sink { [weak self] _ in DispatchQueue.main.async { self?.settingsChanged() } }.store(in: &bag)
        settings.$showDockIcon.sink { [weak self] _ in DispatchQueue.main.async { self?.settingsChanged() } }.store(in: &bag)
        settings.$showMenuBarIcon.sink { [weak self] _ in DispatchQueue.main.async { self?.settingsChanged() } }.store(in: &bag)
        permission.$isTrusted.sink { [weak self] _ in DispatchQueue.main.async { self?.settingsChanged() } }.store(in: &bag)

        let ws = NSWorkspace.shared.notificationCenter
        ws.addObserver(self, selector: #selector(resetMonitor), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(resetMonitor),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // Ask for Accessibility once, on first run; afterwards the settings window explains.
        if !permission.isTrusted && !UserDefaults.standard.bool(forKey: "promptedAccessibility") {
            UserDefaults.standard.set(true, forKey: "promptedAccessibility")
            permission.requestPrompt()
        }

        if !(launchedAtLogin && settings.startHiddenAtLogin && permission.isTrusted) { showSettings() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return false
    }

    private func buildStatusItem() {
        let menu = NSMenu()
        enableItem.target = self
        menu.addItem(enableItem)
        menu.addItem(.separator())
        let prefs = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)
        menu.addItem(NSMenuItem(title: "Quit HoverFocus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.image = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "HoverFocus")
        settingsChanged()
    }

    private func settingsChanged() {
        enableItem.state = settings.enabled ? .on : .off
        statusItem.isVisible = settings.showMenuBarIcon
        let policy: NSApplication.ActivationPolicy = settings.showDockIcon ? .regular : .accessory
        if NSApp.activationPolicy() != policy { NSApp.setActivationPolicy(policy) }
        statusItem.button?.appearsDisabled = !(settings.enabled && permission.isTrusted)
        if settings.enabled { monitor.start() } else { monitor.stop() }
    }

    @objc private func toggleEnabled() { settings.enabled.toggle() }

    @objc private func resetMonitor() {
        monitor.reset()
        permission.refresh()
    }

    @objc func showSettings() {
        if window == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView()))
            w.title = "HoverFocus"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
