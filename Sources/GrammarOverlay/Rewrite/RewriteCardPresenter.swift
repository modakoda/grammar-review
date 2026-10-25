import AppKit
import GrammarModels

final class RewriteCardPresenter {
    private let model = RewriteModel()
    private let actions: OverlayActions
    private var window: PopoverWindow?

    init(actions: OverlayActions) {
        self.actions = actions
    }

    var panel: OverlayPanel? { window?.panel }
    var state: RewriteState? { model.state }
    var isPresented: Bool { window?.panel.isPresented == true }
    var hasKeyboard: Bool { window?.panel.isKeyWindow == true }

    func show(_ state: RewriteState, screens: [ScreenLayout]) {
        let window = ensureWindow()
        if model.state != state {
            model.state = state
            window.contentDidChange()
        }
        window.layout(anchor: state.anchor, screens: screens)
        window.panel.present(animated: true)
    }

    func dismiss() {
        guard let panel = window?.panel else { return }
        let hadKeyboard = panel.isKeyWindow
        panel.giveUpKeyboard()
        panel.dismiss(animated: !hadKeyboard)
    }

    func hide() {
        window?.panel.dismiss(animated: false)
    }

    func giveUpKeyboard() {
        window?.panel.giveUpKeyboard()
    }

    private func ensureWindow() -> PopoverWindow {
        if let window { return window }
        let window = PopoverWindow(content: RewriteCardView(model: model, actions: actions), acceptsKeyboard: true)
        self.window = window
        return window
    }
}
