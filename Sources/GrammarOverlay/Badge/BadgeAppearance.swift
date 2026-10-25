import Foundation
import GrammarModels

nonisolated struct BadgeAppearance: Equatable, Sendable {
    enum Glyph: Equatable, Sendable {
        case count(String)
        case checkmark
        case spinner
        case warning
    }

    enum Tint: Equatable, Sendable {
        case severity(IssueSeverity)
        case success
        case neutral
        case warning
    }

    var glyph: Glyph
    var tint: Tint
    var showsActivityRing: Bool
    var showsWarningDot: Bool
    var tooltip: String

    init(glyph: Glyph, tint: Tint, showsActivityRing: Bool = false, showsWarningDot: Bool = false, tooltip: String) {
        self.glyph = glyph
        self.tint = tint
        self.showsActivityRing = showsActivityRing
        self.showsWarningDot = showsWarningDot
        self.tooltip = tooltip
    }

    init(issues: [TextIssue], status: CheckStatus) {
        guard let severity = IssueSummary.mostSevere(issues) else {
            switch status {
            case .checking:
                self.init(glyph: .spinner, tint: .neutral, tooltip: "Checking…")
            case .done:
                self.init(glyph: .checkmark, tint: .success, tooltip: "No issues found")
            case .aiUnavailable(let message):
                self.init(glyph: .warning, tint: .warning, tooltip: message)
            }
            return
        }

        let title = IssueSummary.title(forCount: issues.count)
        let glyph = Glyph.count(IssueSummary.countLabel(issues.count))
        switch status {
        case .checking:
            self.init(glyph: glyph, tint: .severity(severity), showsActivityRing: true, tooltip: "\(title) · checking…")
        case .done:
            self.init(glyph: glyph, tint: .severity(severity), tooltip: title)
        case .aiUnavailable(let message):
            self.init(glyph: glyph, tint: .severity(severity), showsWarningDot: true, tooltip: "\(title) · \(message)")
        }
    }
}
