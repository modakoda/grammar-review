import AppKit
import GrammarModels

final class BadgePresenter {
    private let model = BadgeModel()
    private let actions: OverlayActions
    private var window: BadgeWindow?
    private var state: OverlayState?

    init(actions: OverlayActions) {
        self.actions = actions
    }

    var panel: OverlayPanel? { window?.panel }

    func render(_ state: OverlayState, circle: CGRect) {
        self.state = state
        let window = ensureWindow()
        let appearance = BadgeAppearance(issues: state.issues.map(\.issue), status: state.status)
        if model.appearance != appearance {
            model.appearance = appearance
            window.host.toolTip = appearance.tooltip
        }
        window.panel.setFrameIfNeeded(BadgeLayout.windowFrame(circleFrame: circle).roundedToPoints())
        window.panel.present(animated: false)
    }

    func hide() {
        state = nil
        window?.panel.dismiss(animated: false)
    }

    private func ensureWindow() -> BadgeWindow {
        if let window { return window }
        let window = BadgeWindow(model: model, actions: actions)
        window.host.contextMenu = { [weak self] in self?.contextMenu() }
        self.window = window
        return window
    }

    private func contextMenu() -> NSMenu? {
        guard let state else { return nil }
        return BadgeMenu.make(
            kind: FieldKind(isSingleLine: state.isSingleLine),
            placement: state.badgePlacement,
            spacing: Double(state.badgeSpacing),
            actions: actions
        )
    }
}
