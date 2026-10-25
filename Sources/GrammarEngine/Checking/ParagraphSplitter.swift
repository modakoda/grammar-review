import Foundation

struct Paragraph: Sendable, Equatable {
    var text: String
    var location: Int

    var range: NSRange { NSRange(location: location, length: text.utf16.count) }
}

enum ParagraphSplitter {
    static let minimumLettersForAI = 4

    static func split(_ text: String) -> [Paragraph] {
        let ns = text as NSString
        let length = ns.length
        guard length > 0 else { return [] }
        let content = CharacterSet.whitespaces.inverted
        var paragraphs: [Paragraph] = []
        var lineStart = 0
        var index = 0
        while index <= length {
            let isEnd = index == length
            let unit: UInt16 = isEnd ? 0 : ns.character(at: index)
            if isEnd || isLineBreak(unit) {
                let line = NSRange(location: lineStart, length: index - lineStart)
                if line.length > 0 {
                    let first = ns.rangeOfCharacter(from: content, options: [], range: line)
                    if first.location != NSNotFound {
                        let last = ns.rangeOfCharacter(from: content, options: .backwards, range: line)
                        let trimmed = NSRange(location: first.location, length: NSMaxRange(last) - first.location)
                        paragraphs.append(Paragraph(text: ns.substring(with: trimmed), location: trimmed.location))
                    }
                }
                lineStart = index + 1
            }
            index += 1
        }
        return paragraphs
    }

    static func isWorthChecking(_ paragraph: Paragraph) -> Bool {
        var letters = 0
        for scalar in paragraph.text.unicodeScalars where CharacterSet.letters.contains(scalar) {
            letters += 1
            if letters >= minimumLettersForAI { return true }
        }
        return false
    }

    private static func isLineBreak(_ unit: UInt16) -> Bool {
        unit == 0x0A || unit == 0x0D || unit == 0x2028 || unit == 0x2029
    }
}
