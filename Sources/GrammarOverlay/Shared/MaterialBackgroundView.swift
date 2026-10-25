import AppKit

final class MaterialBackgroundView: NSVisualEffectView {
    init(cornerRadius: CGFloat = OverlayMetrics.cornerRadius) {
        super.init(frame: NSRect(x: 0, y: 0, width: 10, height: 10))
        material = .popover
        blendingMode = .behindWindow
        state = .active
        maskImage = Self.roundedMask(cornerRadius: cornerRadius)
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private static func roundedMask(cornerRadius radius: CGFloat) -> NSImage? {
        let scale: CGFloat = 2
        let edge = radius * 2 + 1
        let pixels = Int((edge * scale).rounded(.up))
        guard let context = CGContext(
            data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.scaleBy(x: scale, y: scale)
        context.setFillColor(CGColor(gray: 0, alpha: 1))
        let rect = CGRect(x: 0, y: 0, width: edge, height: edge)
        context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
        context.fillPath()
        guard let cgImage = context.makeImage() else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: edge, height: edge))
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
