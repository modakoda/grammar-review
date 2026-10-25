import AppKit
import SwiftUI

final class BadgeWindow {
    let panel = OverlayPanel(level: OverlayLevel.badge)
    let host: FirstMouseHostingView

    init(model: BadgeModel, actions: OverlayActions) {
        host = FirstMouseHostingView(rootView: BadgeView(model: model, actions: actions))
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }
}
