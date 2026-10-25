import Foundation
import GrammarModels

struct ComposeSession: Equatable {
    let id = UUID()
    var request = ""
    var usesText: Bool
    var range: NSRange
    var replaced: String
    var result: RewriteResult?
}
