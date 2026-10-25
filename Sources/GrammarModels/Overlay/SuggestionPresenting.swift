import Foundation

@MainActor
public protocol SuggestionPresenterDelegate: AnyObject {
    func presenter(didAccept replacement: String, for issue: TextIssue)
    func presenter(didIgnore issue: TextIssue)
    func presenter(didRestore issue: TextIssue)
    func presenter(didAddToDictionary issue: TextIssue)
    func presenterDidRequestFixAll()
    func presenter(didRequestRewriteWith tone: RewriteTone)
    func presenter(didRequestRephraseSentenceOf issue: TextIssue)
    func presenter(didRequestRewriteOf scope: RewriteScope, tone: RewriteTone)
    func presenter(didRequestRewriteWithInstruction instruction: String)
    func presenter(didAcceptRewrite text: String)
    func presenterDidCancelRewrite()
    func presenterDidRequestDisableForCurrentApp()
    func presenterDidRequestSettings()
    func presenter(didChooseBadgePlacement placement: BadgePlacement, for kind: FieldKind)
    func presenter(didChooseBadgeSpacing spacing: Double)
    func presenterDidRequestBadgeSettings()
    func presenterDidOpenPanel()
    func presenter(didRequestCompose request: String, usesContext: Bool)
    func presenter(didAcceptCompose text: String)
    func presenterDidCancelCompose()
}

@MainActor
public protocol SuggestionPresenting: AnyObject {
    var delegate: (any SuggestionPresenterDelegate)? { get set }
    func update(_ state: OverlayState)
    func showCard(for issueID: UUID?)
    func togglePanel()
    var isShowingPanel: Bool { get }
    func showRewrite(_ state: RewriteState?)
    func showCompose(_ state: ComposeState?)
    func hideAll()
}
