import AppKit
import GrammarModels
import SwiftUI

public final class OnboardingWindowController {
    private let model: OnboardingModel
    private let closeObserver = WindowCloseObserver()
    private var window: NSWindow?
    private var pollTask: Task<Void, Never>?

    public init(settingsStore: SettingsStore, validateAPIKey: @escaping APIKeyValidator, onFinish: @escaping () -> Void) {
        model = OnboardingModel(
            store: settingsStore,
            keyModel: APIKeyEditorModel(validate: validateAPIKey),
            onFinish: onFinish
        )
        closeObserver.onClose = { [weak self] in self?.windowWillClose() }
    }

    public func show() {
        let window = self.window ?? makeWindow()
        if !window.isVisible {
            model.restart()
        }
        startPolling()
        AppWindows.present(window)
    }

    public var isVisible: Bool {
        window?.isVisible ?? false
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(
            model: model,
            openSystemSettings: { [weak self] in self?.openAccessibilitySettings() },
            resetPermission: { [weak self] in self?.resetAccessibilityPermission() },
            relaunch: { PermissionRepair.relaunch() },
            finish: { [weak self] in self?.finishPressed() }
        )
        let window = AppWindows.makeWindow(title: "Welcome to Grammar Review", contentSize: OnboardingView.size, rootView: view)
        window.identifier = NSUserInterfaceItemIdentifier("onboarding")
        window.delegate = closeObserver
        self.window = window
        return window
    }

    private func openAccessibilitySettings() {
        AccessibilityPermission.requestIfNeeded()
        NSWorkspace.shared.open(AccessibilityPermission.settingsURL)
    }

    private func resetAccessibilityPermission() {
        guard PermissionRepair.resetAccessibility() else {
            model.repairState = .resetFailed
            return
        }
        model.repairState = .resetDone
        openAccessibilitySettings()
    }

    private func finishPressed() {
        model.finish()
        window?.close()
    }

    private func windowWillClose() {
        stopPolling()
        model.windowClosed()
    }

    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard self?.pollPermission() != nil else { return }
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func pollPermission() {
        let justGranted = model.refreshPermission()
        if justGranted, model.step == .accessibility, let window, window.isVisible {
            AppWindows.present(window)
        }
    }
}
