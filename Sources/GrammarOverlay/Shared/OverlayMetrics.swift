import CoreGraphics
import Foundation

nonisolated enum OverlayMetrics {
    static let underlineWindowOutset: CGFloat = 4
    static let underlineThickness: CGFloat = 2
    static let activeUnderlineThickness: CGFloat = 3
    static let hoverInflation: CGFloat = 3

    static let badgeDiameter: CGFloat = 22
    static let badgeInset: CGFloat = 6
    static let badgeOutsideGap: CGFloat = 8
    static let badgeInsideMinFieldHeight: CGFloat = 56
    static let badgePadding: CGFloat = 4

    static let cardWidth: CGFloat = 300
    static let panelWidth: CGFloat = 340
    static let panelMaxWidth: CGFloat = 520
    static let panelMaxHeight: CGFloat = 420
    static let panelMinListHeight: CGFloat = 60
    static let rewriteWidth: CGFloat = 360
    static let rewriteMaxTextHeight: CGFloat = 240
    static let cornerRadius: CGFloat = 10
    static let anchorGap: CGFloat = 4
    static let screenMargin: CGFloat = 4
    static let cardHoverSlack: CGFloat = 2

    static let hoverShowDelay: TimeInterval = 0.15
    static let hoverHideDelay: TimeInterval = 0.3
    static let hoverPollInterval: TimeInterval = 0.1
    static let fadeDuration: TimeInterval = 0.12
    static let keyboardReturnDelay: Duration = .milliseconds(150)
}
