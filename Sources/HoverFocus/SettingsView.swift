import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var permission = AccessibilityPermission.shared
    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginNeedsApproval = LoginItem.status == .requiresApproval
    @State private var loginError: String?
    @State private var showFrontHelp = false
    @State private var toast: String?
    @State private var toastToken = 0

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("HoverFocus").font(.title2.bold())
                    Text("Focus follows your mouse.").foregroundStyle(.secondary)
                }
                Spacer()
                statusBadge
            }

            Toggle("Enable HoverFocus", isOn: $settings.enabled)
                .toggleStyle(.switch).font(.headline)

            Picker("Hover delay", selection: $settings.delay) {
                ForEach(Settings.Delay.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.menu)

            HStack {
                Toggle("Bring hovered window to front", isOn: $settings.raiseOnFocus)
                    .disabled(!SkyLight.isAvailable)
                Button { showFrontHelp.toggle() } label: { Image(systemName: "questionmark.circle") }
                    .buttonStyle(.borderless)
                    .help("What does this do?")
                    .popover(isPresented: $showFrontHelp, arrowEdge: .trailing) { frontHelp }
            }
            Text(frontSummary).font(.caption).foregroundStyle(.secondary)

            Divider()

            Toggle("Launch at Login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
            Toggle("Start hidden at login (don't open this window)", isOn: $settings.startHiddenAtLogin)
                .disabled(!launchAtLogin)
            Toggle("Show Dock icon", isOn: $settings.showDockIcon)
            Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
            if !settings.showMenuBarIcon {
                Text("Open HoverFocus again from Applications to show this window.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if loginNeedsApproval {
                HStack {
                    Text("Approve HoverFocus in Login Items to finish enabling.").font(.caption)
                    Button("Open Login Items") { LoginItem.openSystemSettings() }
                }
            }
            if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Label(permission.isTrusted ? "Accessibility access granted" : "Accessibility access needed",
                      systemImage: permission.isTrusted ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(permission.isTrusted ? .green : .orange)
                if !permission.isTrusted {
                    Text("macOS only lets apps focus other apps' windows with Accessibility access. HoverFocus uses it for nothing else.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Open Accessibility Settings") {
                        permission.requestPrompt()
                        permission.openSystemSettings()
                    }
                }
            }

            HStack {
                Text("Version \(version)").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let toast {
                    Label(toast, systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium)).foregroundStyle(.green)
                        .transition(.opacity)
                }
            }
        }
        .padding(20)
        .frame(width: 400)
        .onChange(of: settings.enabled) { flash($0 ? "HoverFocus enabled" : "HoverFocus paused") }
        .onChange(of: settings.delay) { flash("Hover delay set to \($0.label)") }
        .onChange(of: settings.raiseOnFocus) { flash($0 ? "Hovered windows come to front" : "Hovered windows stay in place") }
        .onChange(of: settings.startHiddenAtLogin) { flash($0 ? "Will start hidden at login" : "Window will open at login") }
        .onChange(of: settings.showDockIcon) { flash($0 ? "Dock icon shown" : "Dock icon hidden") }
        .onChange(of: settings.showMenuBarIcon) { flash($0 ? "Menu bar icon shown" : "Menu bar icon hidden") }
        .onAppear { refreshLogin(); permission.refresh() }
    }

    private var frontSummary: String {
        if !SkyLight.isAvailable { return "This version of macOS can't focus a window without moving it, so hovered windows always come to the front." }
        return settings.raiseOnFocus
            ? "ON: the window under your mouse comes in front of other windows as soon as you hover it."
            : "OFF: the window under your mouse is ready for your first click, but it stays where it is, even if other windows cover it."
    }

    private var frontHelp: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Bring hovered window to front").font(.headline)
            Text("When you rest the mouse on a window, HoverFocus makes it the active one so your first click works. This setting decides whether that window also moves on top of the others.")
            Group {
                Label {
                    Text("**Off (default).** Works like Windows. A window half-hidden behind another stays hidden until you click it. Nothing jumps around while you move the mouse.")
                } icon: { Image(systemName: "rectangle.stack") }
                Label {
                    Text("**On.** Hovering a covered window pulls it to the front, like clicking it would. Handy if you want to see what you're pointing at; but windows can pop in front of each other as the mouse passes.")
                } icon: { Image(systemName: "rectangle.on.rectangle") }
            }
            Text("Example: your video is partly behind a Terminal window. With this off, hovering the video lets you click play right away without the video covering the Terminal.")
                .foregroundStyle(.secondary)
            Text("Some apps, like IntelliJ, always move themselves forward when they receive focus, so HoverFocus only activates them. Click inside them to start typing.")
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .fixedSize(horizontal: false, vertical: true)
        .padding(16)
        .frame(width: 340)
    }

    private var statusBadge: some View {
        let (color, text): (Color, String) =
            !permission.isTrusted ? (.orange, "Needs access") : settings.enabled ? (.green, "Active") : (.gray, "Paused")
        return HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text).font(.caption)
        }
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            try LoginItem.set(on); loginError = nil
            flash(on ? "Launch at Login enabled" : "Launch at Login disabled")
        } catch { loginError = error.localizedDescription }
        refreshLogin()
    }

    /// Brief confirmation that a setting was saved.
    private func flash(_ message: String) {
        toastToken += 1
        let token = toastToken
        withAnimation { toast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if token == toastToken { withAnimation { toast = nil } }
        }
    }

    private func refreshLogin() {
        launchAtLogin = LoginItem.isEnabled
        loginNeedsApproval = LoginItem.status == .requiresApproval
    }
}
