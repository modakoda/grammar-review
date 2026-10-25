import Foundation
import GrammarEngine
import GrammarModels

struct ComposeContext {
    let id = UUID()
    let field: any TextFieldHandle
    let range: NSRange
    let replaced: String
    let context: String
    let style: ComposeInsertion.Style
    let anchor: CGRect
    var request = ""

    func state(result: RewriteResult? = nil) -> ComposeState {
        ComposeState(
            anchor: anchor,
            request: request,
            replacesSelection: range.length > 0,
            hasContext: !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            result: result
        )
    }
}
