import CoreGraphics

extension CGRect {
    func roundedToPoints() -> CGRect {
        CGRect(x: minX.rounded(), y: minY.rounded(), width: width.rounded(.up), height: height.rounded(.up))
    }
}
