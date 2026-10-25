import CoreGraphics
import Foundation
import GrammarModels

nonisolated enum PopoverEdge: Equatable, Sendable {
    case below
    case above
}

nonisolated enum PopoverAlignment: Equatable, Sendable {
    case leading
    case trailing
}

nonisolated struct PopoverPlacement: Equatable, Sendable {
    var frame: CGRect
    var edge: PopoverEdge
}

nonisolated enum PopoverPlacer {
    static func place(
        size: CGSize,
        anchor: CGRect,
        screens: [ScreenLayout],
        alignment: PopoverAlignment = .leading,
        gap: CGFloat = OverlayMetrics.anchorGap,
        margin: CGFloat = OverlayMetrics.screenMargin
    ) -> PopoverPlacement {
        let bounds = ScreenChooser.screen(for: anchor, among: screens)
            .map { $0.visibleFrame.insetBy(dx: margin, dy: margin) }
        return place(size: size, anchor: anchor, within: bounds, alignment: alignment, gap: gap)
    }

    static func place(
        size: CGSize,
        anchor: CGRect,
        within bounds: CGRect?,
        alignment: PopoverAlignment = .leading,
        gap: CGFloat = OverlayMetrics.anchorGap
    ) -> PopoverPlacement {
        let usableBounds = bounds.flatMap { $0.isDrawable ? $0 : nil }
        let width = usableBounds.map { min(size.width, $0.width) } ?? size.width
        let height = usableBounds.map { min(size.height, $0.height) } ?? size.height

        var x = alignment == .leading ? anchor.minX : anchor.maxX - width
        let belowY = anchor.minY - gap - height
        let aboveY = anchor.maxY + gap

        guard let b = usableBounds, anchor.hasFiniteGeometry else {
            return PopoverPlacement(frame: CGRect(x: x, y: belowY, width: width, height: height), edge: .below)
        }

        x = min(max(x, b.minX), b.maxX - width)

        var edge: PopoverEdge
        var y: CGFloat
        if belowY >= b.minY {
            edge = .below
            y = belowY
        } else if aboveY + height <= b.maxY {
            edge = .above
            y = aboveY
        } else {
            let roomBelow = anchor.minY - gap - b.minY
            let roomAbove = b.maxY - aboveY
            if roomBelow >= roomAbove {
                edge = .below
                y = belowY
            } else {
                edge = .above
                y = aboveY
            }
        }
        y = min(max(y, b.minY), b.maxY - height)
        return PopoverPlacement(frame: CGRect(x: x, y: y, width: width, height: height), edge: edge)
    }
}
