import AppKit
import SwiftUI

// Not generic, and neither is PopoverWindow that holds one: Swift 6.3's optimizer crashes on the
// deinit of a generic class around a hosting view in release builds (signal 11 in EarlyPerfInliner).
final class FirstMouseHostingView: NSHostingView<AnyView> {
    var contextMenu: (() -> NSMenu?)?

    convenience init(rootView: some View) {
        self.init(rootView: AnyView(rootView))
    }

    required init(rootView: AnyView) {
        super.init(rootView: rootView)
        sizingOptions = [.intrinsicContentSize]
        for orientation in [NSLayoutConstraint.Orientation.horizontal, .vertical] {
            setContentHuggingPriority(.init(1), for: orientation)
            setContentCompressionResistancePriority(.init(1), for: orientation)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var needsPanelToBecomeKey: Bool { false }

    override func rightMouseDown(with event: NSEvent) {
        if !showContextMenu(for: event) { super.rightMouseDown(with: event) }
    }

    override func mouseDown(with event: NSEvent) {
        if !event.modifierFlags.contains(.control) || !showContextMenu(for: event) { super.mouseDown(with: event) }
    }

    private func showContextMenu(for event: NSEvent) -> Bool {
        guard let menu = contextMenu?() else { return false }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
        return true
    }

    func measuredSize() -> CGSize {
        layoutSubtreeIfNeeded()
        let size = intrinsicContentSize
        guard size.width > 0, size.height > 0,
              size.width != NSView.noIntrinsicMetric, size.height != NSView.noIntrinsicMetric
        else { return fittingSize }
        return size
    }
}
