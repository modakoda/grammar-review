import Foundation
import GrammarAppUI
import GrammarEngine
import GrammarModels

final class OverlayRenderer {
    static let typingSettle = Duration.milliseconds(1200)
    static let maxPositionedIssues = 80

    private let overlay: any SuggestionPresenting
    private let settingsStore: SettingsStore
    private let toneSession: ToneSession
    private var lastState: OverlayState?

    init(overlay: any SuggestionPresenting, settingsStore: SettingsStore, toneSession: ToneSession) {
        self.overlay = overlay
        self.settingsStore = settingsStore
        self.toneSession = toneSession
    }

    var isShowing: Bool { lastState != nil }

    func forgetLastState() {
        lastState = nil
    }

    func hide() {
        lastState = nil
        overlay.hideAll()
    }

    func render(_ session: FieldSession, lastTextChange: Date) {
        let field = session.field
        guard let frame = field.frame(), !session.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            Log.app.debug("Overlay hidden: \(field.frame() == nil ? "field frame unavailable" : "empty text", privacy: .public)")
            if lastState != nil {
                lastState = nil
                overlay.hideAll()
            }
            return
        }

        let caret = recentlyTypedCaret(in: session.field, lastTextChange: lastTextChange)
        let visible = session.issues.filter { !Self.isBeingTyped($0, caret: caret) }
        let positioned = visible.enumerated().map { index, issue in
            PositionedIssue(issue: issue, rects: index < Self.maxPositionedIssues ? field.rects(for: issue.range) : [])
        }
        let settings = settingsStore.settings
        let state = OverlayState(
            fieldFrame: frame,
            isSingleLine: field.isSingleLine,
            issues: positioned,
            status: session.status,
            appName: field.appName,
            showBadge: settings.showBadge,
            badgePlacement: settings.badgePlacement(for: FieldKind(isSingleLine: field.isSingleLine)),
            badgeSpacing: settings.badgeSpacing,
            ignoredIssues: session.ignoredIssues,
            tone: toneReport,
            isDetectingTone: toneSession.isDetecting,
            offersRewrite: settings.aiEnabled
        )
        guard state != lastState else { return }
        lastState = state
        Log.app.debug("Overlay: \(positioned.count, privacy: .public) issues, \(positioned.filter { !$0.rects.isEmpty }.count, privacy: .public) with positions, field \(String(describing: frame), privacy: .public)")
        overlay.update(state)
    }

    private var toneReport: ToneReport? {
        if case .ready(let report) = toneSession.state { report } else { nil }
    }

    private func recentlyTypedCaret(in field: any TextFieldHandle, lastTextChange: Date) -> Int? {
        guard Date().timeIntervalSince(lastTextChange) < Self.typingSettle.seconds,
              let selection = field.selectedRange(), selection.length == 0
        else { return nil }
        return selection.location
    }

    private static func isBeingTyped(_ issue: TextIssue, caret: Int?) -> Bool {
        guard issue.source == .local, let caret else { return false }
        return caret >= issue.range.location && caret <= NSMaxRange(issue.range)
    }
}

private extension Duration {
    var seconds: Double {
        let (seconds, attoseconds) = components
        return Double(seconds) + Double(attoseconds) / 1e18
    }
}
