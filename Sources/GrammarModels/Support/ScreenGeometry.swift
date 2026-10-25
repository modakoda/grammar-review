import CoreGraphics

public enum ScreenGeometry {
    public static var primaryDisplayHeight: CGFloat {
        CGDisplayBounds(CGMainDisplayID()).height
    }

    public static func flip(_ rect: CGRect, primaryHeight: CGFloat = primaryDisplayHeight) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    public static func flip(_ point: CGPoint, primaryHeight: CGFloat = primaryDisplayHeight) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }
}
