import CoreGraphics
import Foundation
import GrammarModels

nonisolated enum VisibleFrame: Equatable, Sendable {
    case unknown
    case hidden
    case visible(CGRect)
}

nonisolated enum RectGeometry {
    static let maxDimension: CGFloat = 10_000
    static let maxCoordinate: CGFloat = 100_000
    static let clipTolerance: CGFloat = 1

    static func isFinite(_ rect: CGRect) -> Bool {
        rect.origin.x.isFinite && rect.origin.y.isFinite && rect.size.width.isFinite && rect.size.height.isFinite
    }

    static func isSane(_ rect: CGRect) -> Bool {
        guard isFinite(rect), !rect.isNull else { return false }
        guard rect.size.width > 0, rect.size.height > 0 else { return false }
        guard rect.width < maxDimension, rect.height < maxDimension else { return false }
        return abs(rect.minX) < maxCoordinate && abs(rect.minY) < maxCoordinate
    }

    static func isAtGlobalOrigin(_ rect: CGRect) -> Bool {
        abs(rect.minX) < 0.5 && abs(rect.minY) < 0.5
    }

    static func isPlausible(_ rect: CGRect, field: CGRect?) -> Bool {
        guard isSane(rect) else { return false }
        let fieldArea = field?.insetBy(dx: -clipTolerance, dy: -clipTolerance)
        if isAtGlobalOrigin(rect), !(fieldArea?.contains(CGPoint.zero) ?? false) { return false }
        if let fieldArea, !rect.intersects(fieldArea) { return false }
        return true
    }

    static func clip(_ rect: CGRect, to field: CGRect) -> CGRect? {
        let clipped = rect.intersection(field.insetBy(dx: -clipTolerance, dy: -clipTolerance))
        guard !clipped.isNull, clipped.width > 0, clipped.height > 0 else { return nil }
        return clipped
    }

    static func screenRects(fromAX rects: [CGRect], visibleField: CGRect?, primaryHeight: CGFloat) -> [CGRect] {
        rects.compactMap { rect -> CGRect? in
            guard isPlausible(rect, field: visibleField) else { return nil }
            let clipped: CGRect? = if let visibleField { clip(rect, to: visibleField) } else { rect }
            return clipped.map { ScreenGeometry.flip($0, primaryHeight: primaryHeight) }
        }
    }

    static func visibleFrame(field: CGRect, clips: [CGRect]) -> VisibleFrame {
        guard isSane(field) else { return .unknown }
        var visible = field
        for clip in clips where isSane(clip) {
            let intersection = visible.intersection(clip)
            guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return .hidden }
            visible = intersection
        }
        return .visible(visible)
    }

    static func onSameLine(_ a: CGRect, _ b: CGRect) -> Bool {
        let overlap = min(a.maxY, b.maxY) - max(a.minY, b.minY)
        return overlap >= 0.5 * min(a.height, b.height)
    }
}
