import Foundation
import GrammarModels
import Observation

@Observable
final class PanelModel {
    var issues: [TextIssue] = []
    var ignored: [TextIssue] = []
    var status: CheckStatus = .done
    var appName: String?
    var tone: ToneReport?
    var isDetectingTone = false
    var offersRewrite = true
    var width = OverlayMetrics.panelWidth
    var showsAllRewriteStyles = false
    @ObservationIgnored var contentSizeDidChange: () -> Void = {}

    func toggleRewriteStyles() {
        showsAllRewriteStyles.toggle()
        contentSizeDidChange()
    }

    func update(from state: OverlayState?) -> Bool {
        var changed = false
        let issues = state?.issues.map(\.issue) ?? []
        if self.issues != issues {
            self.issues = issues
            changed = true
        }
        let ignored = state?.ignoredIssues ?? []
        if self.ignored != ignored {
            self.ignored = ignored
            changed = true
        }
        let status = state?.status ?? .done
        if self.status != status {
            self.status = status
            changed = true
        }
        if appName != state?.appName {
            appName = state?.appName
            changed = true
        }
        if offersRewrite != (state?.offersRewrite ?? true) {
            offersRewrite = state?.offersRewrite ?? true
            changed = true
        }
        if tone != state?.tone || isDetectingTone != (state?.isDetectingTone ?? false) {
            tone = state?.tone
            isDetectingTone = state?.isDetectingTone ?? false
            changed = true
        }
        return changed
    }

    var fixAllCount: Int { IssueSummary.fixAllCount(issues) }
    var isChecking: Bool { status == .checking }
    var aiUnavailableMessage: String? {
        if case .aiUnavailable(let message) = status { return message }
        return nil
    }
}
