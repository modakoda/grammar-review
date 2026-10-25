import Foundation

struct Passage: Sendable, Equatable {
    var range: NSRange
    var text: String
    var words: [String]
}

enum PassageSampler {
    static let minimumWords = 8
    static let maxQueryWords = 32
    static let maxQueryCharacters = 400

    static func passages(in text: String) -> [Passage] {
        ParagraphSplitter.split(text).flatMap { paragraph -> [Passage] in
            var found: [Passage] = []
            let content = paragraph.text
            content.enumerateSubstrings(in: content.startIndex..., options: .bySentences) { sentence, range, _, _ in
                guard let sentence else { return }
                let trimmed = sentence.trimmedWhitespace
                let words = PassageMatcher.words(in: trimmed)
                guard words.count >= minimumWords else { return }
                let local = NSRange(range, in: content)
                let offset = max(0, (sentence as NSString).range(of: trimmed).location)
                found.append(Passage(
                    range: NSRange(location: paragraph.location + local.location + offset, length: (trimmed as NSString).length),
                    text: trimmed,
                    words: words
                ))
            }
            return found
        }
    }

    static func sample(_ passages: [Passage], limit: Int) -> [Passage] {
        guard passages.count > limit, limit > 0 else { return passages }
        let step = Double(passages.count) / Double(limit)
        return (0..<limit).map { passages[Int(Double($0) * step)] }
    }

    static func query(for passage: Passage) -> String {
        var words: [Substring] = []
        var length = 2
        for word in passage.text.split(whereSeparator: \.isWhitespace).prefix(maxQueryWords) {
            let cleaned = word.filter { !"\"\u{201C}\u{201D}\u{201E}\u{00AB}\u{00BB}".contains($0) }
            guard cleaned.contains(where: { $0.isLetter || $0.isNumber }) else { continue }
            guard length + cleaned.count + 1 <= maxQueryCharacters else { break }
            length += cleaned.count + 1
            words.append(Substring(cleaned))
        }
        return "\"\(words.joined(separator: " "))\""
    }
}

enum PassageMatcher {
    static let shingle = 4
    static let threshold = 0.6
    static let minimumCoveredWords = 6

    static func words(in text: String) -> [String] {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    static func coverage(of passage: [String], in texts: [String]) -> (share: Double, words: Int) {
        let size = min(shingle, passage.count)
        guard size > 0 else { return (0, 0) }
        var shingles = Set<ArraySlice<String>>()
        for text in texts {
            let source = words(in: text)
            guard source.count >= size else { continue }
            for start in 0...(source.count - size) { shingles.insert(source[start..<(start + size)]) }
        }
        guard !shingles.isEmpty else { return (0, 0) }
        var covered = [Bool](repeating: false, count: passage.count)
        for start in 0...(passage.count - size) where shingles.contains(passage[start..<(start + size)]) {
            for index in start..<(start + size) { covered[index] = true }
        }
        let count = covered.count(where: \.self)
        return (Double(count) / Double(passage.count), count)
    }

    static func matches(_ passage: Passage, _ result: WebSearchResult) -> Double? {
        let (share, count) = coverage(of: passage.words, in: [result.title, result.description] + result.snippets)
        return share >= threshold && count >= min(minimumCoveredWords, passage.words.count) ? share : nil
    }
}
