import CoreGraphics
import Foundation
import GrammarModels

nonisolated struct UnderlineSegment: Equatable, Sendable {
    var issueID: UUID
    var severity: IssueSeverity
    var textRect: CGRect
    var barRect: CGRect

    func offsetBy(dx: CGFloat, dy: CGFloat) -> UnderlineSegment {
        UnderlineSegment(
            issueID: issueID,
            severity: severity,
            textRect: textRect.offsetBy(dx: dx, dy: dy),
            barRect: barRect.offsetBy(dx: dx, dy: dy)
        )
    }
}

nonisolated enum UnderlineLayout {
    static func windowFrame(
        fieldFrame: CGRect,
        outset: CGFloat = OverlayMetrics.underlineWindowOutset
    ) -> CGRect {
        fieldFrame.insetBy(dx: -outset, dy: -outset)
    }

    static func segments(
        for issues: [PositionedIssue],
        fieldFrame: CGRect,
        thickness: CGFloat = OverlayMetrics.underlineThickness,
        tolerance: CGFloat = OverlayMetrics.underlineWindowOutset
    ) -> [UnderlineSegment] {
        guard fieldFrame.isDrawable else { return [] }
        var result: [UnderlineSegment] = []
        for positioned in issues {
            let severity = positioned.issue.category.severity
            for rect in positioned.rects {
                guard let segment = segment(
                    for: rect, issueID: positioned.id, severity: severity,
                    fieldFrame: fieldFrame, thickness: thickness, tolerance: tolerance
                ) else { continue }
                result.append(segment)
            }
        }
        return result
    }

    static func segment(
        for rect: CGRect,
        issueID: UUID,
        severity: IssueSeverity,
        fieldFrame: CGRect,
        thickness: CGFloat = OverlayMetrics.underlineThickness,
        tolerance: CGFloat = OverlayMetrics.underlineWindowOutset
    ) -> UnderlineSegment? {
        guard rect.isDrawable else { return nil }
        let visible = rect.intersection(fieldFrame)
        guard !visible.isNull, visible.width >= 1, visible.height > 0 else { return nil }
        guard rect.minY >= fieldFrame.minY - tolerance, rect.minY <= fieldFrame.maxY else { return nil }
        let bar = CGRect(x: visible.minX, y: rect.minY - thickness / 2, width: visible.width, height: thickness)
        return UnderlineSegment(issueID: issueID, severity: severity, textRect: visible, barRect: bar)
    }
}
