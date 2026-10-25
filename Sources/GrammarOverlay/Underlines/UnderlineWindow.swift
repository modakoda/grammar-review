import AppKit

final class UnderlineWindow {
    let panel = OverlayPanel(level: OverlayLevel.underlines, clickThrough: true)
    let view = UnderlineView(frame: NSRect(x: 0, y: 0, width: 10, height: 10))

    init() {
        panel.contentView = view
    }
}
