import CoreGraphics
import Foundation
import GrammarModels

nonisolated enum BadgeLayout {
    struct Spot: Equatable, Sendable {
        enum Side: Equatable, Sendable { case left, right }
        enum End: Equatable, Sendable { case top, bottom }
        enum Offset: Equatable, Sendable {
            case inside
            case outsideSideways
            case outsideVertically
        }

        var side: Side
        var end: End
        var offset: Offset

        static let insideBottomRight = Spot(side: .right, end: .bottom, offset: .inside)
        static let insideTopRight = Spot(side: .right, end: .top, offset: .inside)
        static let insideBottomLeft = Spot(side: .left, end: .bottom, offset: .inside)
        static let insideTopLeft = Spot(side: .left, end: .top, offset: .inside)
        static let right = Spot(side: .right, end: .bottom, offset: .outsideSideways)
        static let left = Spot(side: .left, end: .bottom, offset: .outsideSideways)
        static let above = Spot(side: .right, end: .top, offset: .outsideVertically)
        static let below = Spot(side: .right, end: .bottom, offset: .outsideVertically)

        var inside: Spot { Spot(side: side, end: end, offset: .inside) }
    }

    static func circleFrame(
        fieldFrame: CGRect,
        isSingleLine: Bool = false,
        placement: BadgePlacement = .insideBottomRight,
        screens: [ScreenLayout],
        diameter: CGFloat = OverlayMetrics.badgeDiameter,
        inset: CGFloat = OverlayMetrics.badgeInset,
        gap: CGFloat = OverlayMetrics.badgeOutsideGap,
        margin: CGFloat = OverlayMetrics.badgePadding
    ) -> CGRect {
        let bounds = ScreenChooser.screen(for: fieldFrame, among: screens)
            .map { $0.visibleFrame.insetBy(dx: margin, dy: margin) }
            .flatMap { $0.isDrawable ? $0 : nil }

        let spots = candidates(for: placement, fieldFrame: fieldFrame, isSingleLine: isSingleLine, diameter: diameter, inset: inset)
        for spot in spots {
            var circle = frame(at: spot, fieldFrame: fieldFrame, diameter: diameter, inset: inset, gap: gap)
            if isSingleLine, spot.offset == .outsideSideways {
                circle.origin.y = fieldFrame.midY - diameter / 2
            }
            guard let bounds else { return circle }
            let clamped = circle.clamped(into: bounds)
            if spot.offset == .inside || !clamped.intersects(fieldFrame) { return clamped }
        }
        return frame(at: .insideBottomRight, fieldFrame: fieldFrame, diameter: diameter, inset: inset, gap: gap)
    }

    static func candidates(
        for placement: BadgePlacement,
        fieldFrame: CGRect,
        isSingleLine: Bool = false,
        diameter: CGFloat = OverlayMetrics.badgeDiameter,
        inset: CGFloat = OverlayMetrics.badgeInset
    ) -> [Spot] {
        switch placement {
        case .insideBottomRight: [.insideBottomRight]
        case .insideTopRight: [.insideTopRight]
        case .insideBottomLeft: [.insideBottomLeft]
        case .insideTopLeft: [.insideTopLeft]
        case .right: outside(preferring: .right)
        case .left: outside(preferring: .left)
        case .above: outside(preferring: .above)
        case .below: outside(preferring: .below)
        case .automatic:
            !isSingleLine && isRoomyEnough(fieldFrame, diameter: diameter, inset: inset)
                ? [.insideBottomLeft] : outside(preferring: .left)
        }
    }

    private static func outside(preferring preferred: Spot) -> [Spot] {
        [preferred] + [Spot.right, .below, .above, .left].filter { $0 != preferred } + [preferred.inside]
    }

    static func isRoomyEnough(
        _ fieldFrame: CGRect,
        diameter: CGFloat = OverlayMetrics.badgeDiameter,
        inset: CGFloat = OverlayMetrics.badgeInset
    ) -> Bool {
        fieldFrame.height >= OverlayMetrics.badgeInsideMinFieldHeight && fieldFrame.width >= diameter + 2 * inset
    }

    private static func frame(at spot: Spot, fieldFrame: CGRect, diameter: CGFloat, inset: CGFloat, gap: CGFloat) -> CGRect {
        let needed = diameter + 2 * inset
        let insideX = fieldFrame.width < needed ? fieldFrame.midX - diameter / 2
            : spot.side == .right ? fieldFrame.maxX - inset - diameter : fieldFrame.minX + inset
        let insideY = fieldFrame.height < needed ? fieldFrame.midY - diameter / 2
            : spot.end == .bottom ? fieldFrame.minY + inset : fieldFrame.maxY - inset - diameter
        let origin = switch spot.offset {
        case .inside:
            CGPoint(x: insideX, y: insideY)
        case .outsideSideways:
            CGPoint(x: spot.side == .right ? fieldFrame.maxX + gap : fieldFrame.minX - gap - diameter, y: insideY)
        case .outsideVertically:
            CGPoint(x: insideX, y: spot.end == .bottom ? fieldFrame.minY - gap - diameter : fieldFrame.maxY + gap)
        }
        return CGRect(origin: origin, size: CGSize(width: diameter, height: diameter))
    }

    static func windowFrame(
        circleFrame: CGRect,
        padding: CGFloat = OverlayMetrics.badgePadding
    ) -> CGRect {
        circleFrame.insetBy(dx: -padding, dy: -padding)
    }
}
