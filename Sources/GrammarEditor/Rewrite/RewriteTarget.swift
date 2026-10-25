import Foundation
import GrammarEngine
import GrammarModels

struct RewriteTarget: Equatable {
    var range: NSRange
    var scope: RewriteScope

    static func selectionOrParagraph(_ selection: NSRange, in text: String) -> RewriteTarget? {
        let ns = text as NSString
        guard ns.length > 0 else { return nil }
        let caret = NSRange(location: min(selection.location, ns.length), length: 0)
        let candidates = selection.length > 0 && NSMaxRange(selection) <= ns.length
            ? [RewriteTarget(range: selection, scope: .selection)]
            : [
                RewriteTarget(range: ns.paragraphRange(for: caret), scope: .paragraph),
                RewriteTarget(range: NSRange(location: 0, length: ns.length), scope: .paragraph),
            ]
        for candidate in candidates {
            if let trimmed = SentenceLocator.trimmed(candidate.range, in: text) {
                return RewriteTarget(range: trimmed, scope: candidate.scope)
            }
        }
        return nil
    }

    static func sentence(around range: NSRange, in text: String) -> RewriteTarget? {
        SentenceLocator.sentence(around: range, in: text).map { RewriteTarget(range: $0, scope: .sentence) }
    }
}
