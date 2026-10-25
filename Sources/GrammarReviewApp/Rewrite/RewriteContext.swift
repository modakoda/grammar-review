import Foundation
import GrammarModels

struct RewriteContext {
    let id = UUID()
    let field: any TextFieldHandle
    let range: NSRange
    let original: String
    let scope: RewriteScope
    let anchor: CGRect

    func state(_ goal: RewriteGoal, result: RewriteResult) -> RewriteState {
        switch goal {
        case .tone(let tone):
            RewriteState(anchor: anchor, original: original, scope: scope, tone: tone, result: result)
        case .instruction(let instruction):
            RewriteState(anchor: anchor, original: original, scope: scope, tone: nil, instruction: instruction, result: result)
        }
    }
}
