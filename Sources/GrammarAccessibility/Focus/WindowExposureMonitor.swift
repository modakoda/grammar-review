import AppKit
import ApplicationServices
import GrammarModels

final class WindowExposureMonitor {
    private var state = HiddenWindowsState()

    var isHidden: Bool { state.isHidden }

    func record(focused: AXElement, in observation: AppObservation) -> Bool {
        let focusedIsApp = focused.isSame(as: observation.app)
        let window = focusedIsApp ? observation.app.element(kAXFocusedWindowAttribute) : nil
        let exposure = WindowExposure.classify(
            focusedIsApp: focusedIsApp,
            focusedWindowIsApp: window.map { $0.isSame(as: observation.app) }
        )
        guard state.record(exposure) else { return false }
        let name = observation.bundleID ?? "pid \(observation.pid)"
        if state.isHidden {
            Log.accessibility.error("macOS hides app windows from Accessibility: \(name, privacy: .public) returns itself as its focused element and window. Log out or restart to fix it.")
        } else {
            let role = focused.string(kAXRoleAttribute) ?? "?"
            Log.accessibility.info("App windows are visible to Accessibility again (\(name, privacy: .public), \(role, privacy: .public))")
        }
        return true
    }

    func reset() -> Bool {
        state.reset()
    }
}
