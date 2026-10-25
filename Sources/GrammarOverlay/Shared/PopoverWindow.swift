import AppKit
import SwiftUI

final class PopoverWindow<Content: View> {
    let panel: OverlayPanel
    let host: FirstMouseHostingView<Content>
    private var measuredSize: CGSize?

    init(content: Content, acceptsKeyboard: Bool = false) {
        panel = OverlayPanel(level: OverlayLevel.popover, hasShadow: true, acceptsKeyboard: acceptsKeyboard)
        let background = MaterialBackgroundView()
        host = FirstMouseHostingView(rootView: content)
        host.frame = background.bounds
        host.autoresizingMask = [.width, .height]
        background.addSubview(host)
        panel.contentView = background
    }

    func contentDidChange() {
        measuredSize = nil
    }

    @discardableResult
    func layout(anchor: CGRect, screens: [ScreenLayout], alignment: PopoverAlignment = .leading) -> PopoverPlacement {
        let size = measuredSize ?? host.measuredSize()
        measuredSize = size
        let placement = PopoverPlacer.place(size: size, anchor: anchor, screens: screens, alignment: alignment)
        panel.setFrameIfNeeded(placement.frame.roundedToPoints())
        return placement
    }
}
