import AppKit
import GrammarModels

final class ComposeCardPresenter {
    private let model = ComposeModel()
    private let actions: OverlayActions
    private var window: PopoverWindow<ComposeCardView>?

    init(actions: OverlayActions) {
        self.actions = actions
    }

    var panel: OverlayPanel? { window?.panel }
    var state: ComposeState? { model.state }
    var isPresented: Bool { window?.panel.isPresented == true }
    var hasKeyboard: Bool { window?.panel.isKeyWindow == true }

    func show(_ state: ComposeState, screens: [ScreenLayout], takesKeyboard: Bool) {
        let window = ensureWindow()
        if model.state != state {
            model.state = state
            window.contentDidChange()
        }
        window.layout(anchor: state.anchor, screens: screens)
        window.panel.present(animated: true)
        if takesKeyboard { window.panel.makeKey() }
    }

    func dismiss() {
        guard let panel = window?.panel else { return }
        panel.giveUpKeyboard()
        panel.dismiss(animated: false)
    }

    private func ensureWindow() -> PopoverWindow<ComposeCardView> {
        if let window { return window }
        let window = PopoverWindow(content: ComposeCardView(model: model, actions: actions), acceptsKeyboard: true)
        self.window = window
        return window
    }
}
