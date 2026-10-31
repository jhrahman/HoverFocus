import ServiceManagement

/// Launch at Login via SMAppService (macOS 13+).
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }
    static var isEnabled: Bool { status == .enabled }

    static func set(_ on: Bool) throws {
        if on {
            if status != .enabled { try SMAppService.mainApp.register() }
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    static func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
