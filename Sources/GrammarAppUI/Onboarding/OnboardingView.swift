import SwiftUI

struct OnboardingView: View {
    static let size = NSSize(width: 580, height: 480)

    @Bindable var model: OnboardingModel
    var openSystemSettings: () -> Void
    var resetPermission: () -> Void
    var relaunch: () -> Void
    var finish: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch model.step {
                case .welcome: WelcomeStep()
                case .accessibility:
                    AccessibilityStep(
                        isTrusted: model.isTrusted,
                        repairState: model.repairState,
                        openSystemSettings: openSystemSettings,
                        resetPermission: resetPermission,
                        relaunch: relaunch
                    )
                case .apiKey: APIKeyStep(keyModel: model.keyModel, modelID: model.store.settings.aiModel)
                case .done: DoneStep(isTrusted: model.isTrusted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)

            Divider()

            HStack(spacing: 10) {
                StepDots(current: model.step)
                Spacer()
                if !model.isFirstStep {
                    Button("Back") { model.back() }
                }
                primaryButtons
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }

    @ViewBuilder
    private var primaryButtons: some View {
        switch model.step {
        case .welcome:
            Button("Get Started") { model.next() }
                .keyboardShortcut(.defaultAction)
        case .accessibility:
            if model.isTrusted {
                Button("Continue") { model.next() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Skip for Now") { model.next() }
                Button("Continue") { model.next() }
                    .disabled(true)
            }
        case .apiKey:
            if model.keyModel.canSave {
                Button("Save & Continue") { model.saveKeyAndContinue() }
                    .keyboardShortcut(.defaultAction)
            } else if model.keyModel.source != .none {
                Button("Continue") { model.next() }
                    .keyboardShortcut(.defaultAction)
            } else {
                Button("Skip") { model.next() }
                    .keyboardShortcut(.defaultAction)
            }
        case .done:
            Button("Finish", action: finish)
                .keyboardShortcut(.defaultAction)
        }
    }
}
