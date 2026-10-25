import AppKit
import GrammarAppUI
import GrammarModels

final class MenuStatusReporter {
    var onChange: ((MenuBarStatus) -> Void)?
    var checkStatus: () -> CheckStatus = { .done }

    private let settingsStore: SettingsStore
    private let tracker: any FocusTracking
    private var permissionTask: Task<Void, Never>?

    init(settingsStore: SettingsStore, tracker: any FocusTracking) {
        self.settingsStore = settingsStore
        self.tracker = tracker
    }

    func update() {
        let settings = settingsStore.settings
        let menuStatus: MenuBarStatus
        if !AccessibilityPermission.isTrusted {
            menuStatus = .needsPermission
        } else if !settings.isActive() {
            menuStatus = .paused
        } else if tracker.windowsAreHidden {
            menuStatus = .windowsHidden
        } else if let app = NSWorkspace.shared.frontmostApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  !settings.allowsApp(app.bundleIdentifier) {
            menuStatus = .disabledForApp(app.localizedName ?? app.bundleIdentifier ?? "this app")
        } else if case .aiUnavailable(let message) = checkStatus() {
            menuStatus = .aiUnavailable(message)
        } else {
            menuStatus = .active
        }
        onChange?(menuStatus)
    }

    func watchPermission() {
        permissionTask?.cancel()
        guard !AccessibilityPermission.isTrusted else { return }
        permissionTask = Task { [weak self] in
            while !Task.isCancelled, !AccessibilityPermission.isTrusted {
                try? await Task.sleep(for: .seconds(2))
            }
            self?.update()
        }
    }
}
