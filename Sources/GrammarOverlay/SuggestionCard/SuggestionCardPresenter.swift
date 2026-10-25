import AppKit
import GrammarModels

final class SuggestionCardPresenter {
    private let model = CardModel()
    private let actions: OverlayActions
    private var window: PopoverWindow?

    init(actions: OverlayActions) {
        self.actions = actions
    }

    var panel: OverlayPanel? { window?.panel }

    func show(_ issue: TextIssue, anchor: CGRect, offersRewrite: Bool, screens: [ScreenLayout]) {
        let window = ensureWindow()
        if model.issue != issue || model.offersRewrite != offersRewrite {
            model.issue = issue
            model.offersRewrite = offersRewrite
            window.contentDidChange()
        }
        window.layout(anchor: anchor, screens: screens)
        window.panel.present(animated: true)
    }

    func hide(animated: Bool) {
        window?.panel.dismiss(animated: animated)
    }

    private func ensureWindow() -> PopoverWindow {
        if let window { return window }
        let window = PopoverWindow(content: SuggestionCardView(model: model, actions: actions))
        self.window = window
        return window
    }
}
