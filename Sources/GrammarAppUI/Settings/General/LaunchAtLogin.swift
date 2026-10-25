import AppKit
import ServiceManagement

enum LaunchAtLogin {
    enum Failure: LocalizedError {
        case notInAppBundle

        var errorDescription: String? {
            switch self {
            case .notInAppBundle:
                "Launch at login works only from the app bundle. Build it with scripts/build-app.sh."
            }
        }
    }

    static var isRunningFromAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static var isEnabled: Bool? {
        guard isRunningFromAppBundle else { return nil }
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: return true
        default: return false
        }
    }

    static var needsApproval: Bool {
        isRunningFromAppBundle && SMAppService.mainApp.status == .requiresApproval
    }

    static func setEnabled(_ enabled: Bool) throws {
        guard isRunningFromAppBundle else { throw Failure.notInAppBundle }
        let service = SMAppService.mainApp
        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
        } else {
            guard service.status != .notRegistered else { return }
            try service.unregister()
        }
    }

    static func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
