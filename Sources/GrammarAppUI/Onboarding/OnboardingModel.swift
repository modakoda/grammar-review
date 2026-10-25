import Foundation
import GrammarModels
import Observation

@Observable
final class OnboardingModel {
    enum Step: Int, CaseIterable {
        case welcome, accessibility, apiKey, done
    }

    var step: Step = .welcome
    private(set) var isTrusted: Bool
    var repairState: PermissionRepairState = .idle
    let keyModel: APIKeyEditorModel

    @ObservationIgnored let store: SettingsStore
    @ObservationIgnored private let permissionCheck: () -> Bool
    @ObservationIgnored private let onFinish: () -> Void
    @ObservationIgnored private(set) var hasFinished = false

    init(
        store: SettingsStore,
        keyModel: APIKeyEditorModel,
        permissionCheck: @escaping () -> Bool = { AccessibilityPermission.isTrusted },
        onFinish: @escaping () -> Void
    ) {
        self.store = store
        self.keyModel = keyModel
        self.permissionCheck = permissionCheck
        self.onFinish = onFinish
        isTrusted = permissionCheck()
    }

    var isFirstStep: Bool { step == .welcome }

    func next() {
        step = Step(rawValue: step.rawValue + 1) ?? .done
    }

    func back() {
        step = Step(rawValue: step.rawValue - 1) ?? .welcome
    }

    @discardableResult
    func refreshPermission() -> Bool {
        let trusted = permissionCheck()
        let justGranted = trusted && !isTrusted
        if trusted != isTrusted {
            isTrusted = trusted
        }
        return justGranted
    }

    func saveKeyAndContinue() {
        if keyModel.canSave, !keyModel.save() { return }
        next()
    }

    func finish() {
        guard !hasFinished else { return }
        store.settings.hasCompletedOnboarding = true
        finishOnce()
    }

    func windowClosed() {
        if step == .done {
            store.settings.hasCompletedOnboarding = true
        }
        finishOnce()
    }

    func restart() {
        step = .welcome
        hasFinished = false
        repairState = .idle
        keyModel.draft = ""
        keyModel.refresh()
        refreshPermission()
    }

    private func finishOnce() {
        guard !hasFinished else { return }
        hasFinished = true
        keyModel.cancelTest()
        onFinish()
    }
}

enum PermissionRepairState: Equatable {
    case idle
    case resetDone
    case resetFailed
}
