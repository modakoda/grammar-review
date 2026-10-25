import Foundation
import GrammarModels

struct OverlayActions {
    var accept: (_ replacement: String, _ issue: TextIssue) -> Void
    var ignore: (TextIssue) -> Void
    var restore: (TextIssue) -> Void
    var addToDictionary: (TextIssue) -> Void
    var fixAll: () -> Void
    var openSettings: () -> Void
    var disableForCurrentApp: () -> Void
    var setBadgePlacement: (BadgePlacement, FieldKind) -> Void
    var setBadgeSpacing: (Double) -> Void
    var openBadgeSettings: () -> Void
    var toggleSuggestions: () -> Void
    var requestRewrite: (RewriteTone) -> Void
    var rephraseSentence: (TextIssue) -> Void
    var rewriteText: (RewriteScope, RewriteTone) -> Void
    var requestInstructionRewrite: (String) -> Void
    var acceptRewrite: (String) -> Void
    var cancelRewrite: () -> Void
    var requestCompose: (_ request: String, _ usesContext: Bool) -> Void
    var acceptCompose: (String) -> Void
    var cancelCompose: () -> Void
}
