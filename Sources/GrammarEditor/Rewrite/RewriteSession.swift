import Foundation
import GrammarModels

enum RewriteGoal: Equatable {
    case tone(RewriteTone)
    case instruction(String)

    var tone: RewriteTone? {
        if case .tone(let tone) = self { tone } else { nil }
    }

    var instruction: String? {
        if case .instruction(let instruction) = self { instruction } else { nil }
    }
}

struct RewriteSession: Equatable {
    let id = UUID()
    var range: NSRange
    var scope: RewriteScope
    var original: String
    var goal: RewriteGoal
    var result: RewriteResult?
}
