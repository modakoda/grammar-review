import CoreGraphics
import Foundation

nonisolated struct ScreenLayout: Equatable, Sendable {
    var frame: CGRect
    var visibleFrame: CGRect

    init(frame: CGRect, visibleFrame: CGRect? = nil) {
        self.frame = frame
        self.visibleFrame = visibleFrame ?? frame
    }
}

nonisolated enum ScreenChooser {
    static func screen(for rect: CGRect, among screens: [ScreenLayout]) -> ScreenLayout? {
        guard let first = screens.first else { return nil }
        guard rect.hasFiniteGeometry else { return first }

        var best: ScreenLayout?
        var bestArea: CGFloat = 0
        for screen in screens {
            let overlap = screen.frame.intersection(rect)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > bestArea {
                best = screen
                bestArea = area
            }
        }
        if let best { return best }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        if let containing = screens.first(where: { $0.frame.containsInclusive(center) }) {
            return containing
        }
        return screens.min { $0.frame.distance(to: center) < $1.frame.distance(to: center) }
    }
}

nonisolated enum CoordinateConversion {
    static func toWindow(_ rect: CGRect, windowFrame: CGRect) -> CGRect {
        rect.offsetBy(dx: -windowFrame.minX, dy: -windowFrame.minY)
    }

    static func toWindow(_ point: CGPoint, windowFrame: CGRect) -> CGPoint {
        CGPoint(x: point.x - windowFrame.minX, y: point.y - windowFrame.minY)
    }

    static func toScreen(_ rect: CGRect, windowFrame: CGRect) -> CGRect {
        rect.offsetBy(dx: windowFrame.minX, dy: windowFrame.minY)
    }

    static func toFlippedWindow(_ rect: CGRect, windowFrame: CGRect) -> CGRect {
        CGRect(
            x: rect.minX - windowFrame.minX,
            y: windowFrame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
    }
}

nonisolated extension CGRect {
    var hasFiniteGeometry: Bool {
        !isNull && !isInfinite
            && origin.x.isFinite && origin.y.isFinite
            && size.width.isFinite && size.height.isFinite
    }

    var isDrawable: Bool {
        hasFiniteGeometry && width > 0 && height > 0
    }

    func containsInclusive(_ point: CGPoint) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    func distance(to point: CGPoint) -> CGFloat {
        let dx = Swift.max(minX - point.x, 0, point.x - maxX)
        let dy = Swift.max(minY - point.y, 0, point.y - maxY)
        return (dx * dx + dy * dy).squareRoot()
    }

    func clamped(into bounds: CGRect) -> CGRect {
        let width = Swift.min(self.width, bounds.width)
        let height = Swift.min(self.height, bounds.height)
        let x = Swift.min(Swift.max(minX, bounds.minX), bounds.maxX - width)
        let y = Swift.min(Swift.max(minY, bounds.minY), bounds.maxY - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
