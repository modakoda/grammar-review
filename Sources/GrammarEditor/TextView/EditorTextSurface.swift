import Foundation
import GrammarModels

protocol EditorTextSurface: AnyObject {
    @discardableResult
    func replaceText(in range: NSRange, with replacement: String) -> Bool
    func reveal(_ range: NSRange)
    func decorate(_ decorations: EditorDecorations)
}

struct EditorDecorations: Equatable {
    struct Underline: Equatable {
        var range: NSRange
        var severity: IssueSeverity
    }

    var underlines: [Underline] = []
    var active: NSRange?
    var rewriteTarget: NSRange?
    var longSentences: [NSRange] = []
    var plagiarism: [NSRange] = []
    var selectedPlagiarism: [NSRange] = []
}
