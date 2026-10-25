import AppKit
import GrammarModels

final class SuggestionsPanelPresenter {
    private let model = PanelModel()
    private let actions: OverlayActions
    private var window: SuggestionsPanelWindow?
    private(set) var isOpen = false

    init(actions: OverlayActions) {
        self.actions = actions
    }

    var panel: OverlayPanel? { window?.panel }

    func open(_ state: OverlayState?, anchor: CGRect, alignment: PopoverAlignment, screens: [ScreenLayout]) {
        isOpen = true
        render(state, anchor: anchor, alignment: alignment, screens: screens)
        let window = ensureWindow()
        window.scrollToTop()
        window.panel.present(animated: true)
    }

    func render(_ state: OverlayState?, anchor: CGRect, alignment: PopoverAlignment, screens: [ScreenLayout]) {
        guard isOpen else { return }
        let window = ensureWindow()
        if model.update(from: state) { window.contentDidChange() }
        window.layout(anchor: anchor, alignment: alignment, screens: screens)
    }

    @discardableResult
    func close() -> Bool {
        guard isOpen else { return false }
        isOpen = false
        window?.panel.dismiss(animated: true)
        return true
    }

    func hide() {
        isOpen = false
        window?.panel.dismiss(animated: false)
    }

    private func ensureWindow() -> SuggestionsPanelWindow {
        if let window { return window }
        let window = SuggestionsPanelWindow(model: model, actions: actions)
        self.window = window
        return window
    }
}
