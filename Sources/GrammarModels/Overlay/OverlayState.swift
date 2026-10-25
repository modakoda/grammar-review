import CoreGraphics
import Foundation

public struct PositionedIssue: Sendable, Equatable, Identifiable {
    public var issue: TextIssue
    public var rects: [CGRect]

    public var id: UUID { issue.id }

    public init(issue: TextIssue, rects: [CGRect]) {
        self.issue = issue
        self.rects = rects
    }
}

public enum CheckStatus: Sendable, Equatable {
    case checking
    case done
    case aiUnavailable(String)
}

public struct OverlayState: Sendable, Equatable {
    public var fieldFrame: CGRect
    public var isSingleLine: Bool
    public var issues: [PositionedIssue]
    public var status: CheckStatus
    public var appName: String?
    public var showBadge: Bool
    public var badgePlacement: BadgePlacement
    public var badgeSpacing: CGFloat
    public var ignoredIssues: [TextIssue]
    public var tone: ToneReport?
    public var isDetectingTone: Bool
    public var offersRewrite: Bool

    public init(
        fieldFrame: CGRect,
        isSingleLine: Bool = false,
        issues: [PositionedIssue],
        status: CheckStatus,
        appName: String?,
        showBadge: Bool,
        badgePlacement: BadgePlacement = .automatic,
        badgeSpacing: CGFloat = AppSettings.defaultBadgeSpacing,
        ignoredIssues: [TextIssue] = [],
        tone: ToneReport? = nil,
        isDetectingTone: Bool = false,
        offersRewrite: Bool = true
    ) {
        self.fieldFrame = fieldFrame
        self.isSingleLine = isSingleLine
        self.issues = issues
        self.status = status
        self.appName = appName
        self.showBadge = showBadge
        self.badgePlacement = badgePlacement
        self.badgeSpacing = badgeSpacing
        self.ignoredIssues = ignoredIssues
        self.tone = tone
        self.isDetectingTone = isDetectingTone
        self.offersRewrite = offersRewrite
    }
}
