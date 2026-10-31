import Foundation

/// User preferences, persisted in UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()

    enum Delay: Int, CaseIterable, Identifiable {
        case instant = 0, ms100 = 100, ms250 = 250, ms500 = 500, ms1000 = 1000
        var id: Int { rawValue }
        var label: String { self == .instant ? "Instant" : "\(rawValue) ms" }
        var seconds: TimeInterval { TimeInterval(rawValue) / 1000 }
    }

    private let defaults = UserDefaults.standard

    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: "enabled") } }
    @Published var delay: Delay { didSet { defaults.set(delay.rawValue, forKey: "delayMs") } }
    @Published var startHiddenAtLogin: Bool { didSet { defaults.set(startHiddenAtLogin, forKey: "startHidden") } }
    @Published var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: "showMenuIcon") } }

    @Published var raiseOnFocus: Bool { didSet { defaults.set(raiseOnFocus, forKey: "raiseOnFocus") } }
    @Published var showDockIcon: Bool { didSet { defaults.set(showDockIcon, forKey: "showDockIcon") } }

    private init() {
        defaults.register(defaults: ["enabled": true, "delayMs": 250, "startHidden": true, "showMenuIcon": true, "showDockIcon": true, "raiseOnFocus": false])
        raiseOnFocus = defaults.bool(forKey: "raiseOnFocus")
        showDockIcon = defaults.bool(forKey: "showDockIcon")
        enabled = defaults.bool(forKey: "enabled")
        delay = Delay(rawValue: defaults.integer(forKey: "delayMs")) ?? .ms250
        startHiddenAtLogin = defaults.bool(forKey: "startHidden")
        showMenuBarIcon = defaults.bool(forKey: "showMenuIcon")
    }
}
