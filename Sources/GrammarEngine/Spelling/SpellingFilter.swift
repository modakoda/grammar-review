import Foundation
import GrammarModels

enum SpellingFilter {
    static func protectedRanges(in text: String) -> [NSRange] {
        let ns = text as NSString
        let whole = NSRange(location: 0, length: ns.length)
        var ranges: [NSRange] = []

        for regex in Patterns.all {
            regex.enumerateMatches(in: text, options: [], range: whole) { match, _, _ in
                if let match { ranges.append(match.range) }
            }
        }
        if let detector = Patterns.links {
            detector.enumerateMatches(in: text, options: [], range: whole) { match, _, _ in
                if let match { ranges.append(match.range) }
            }
        }
        Patterns.token.enumerateMatches(in: text, options: [], range: whole) { match, _, _ in
            guard let match else { return }
            let token = trimmedToken(ns.substring(with: match.range))
            if looksLikeCode(token) { ranges.append(match.range) }
        }
        return ranges
    }

    static func isIgnorableWord(_ word: String, settings: AppSettings) -> Bool {
        let trimmed = word.trimmedWhitespace
        guard !trimmed.isEmpty else { return true }
        if settings.isInPersonalDictionary(trimmed) { return true }
        return looksLikeCode(trimmed) || isAcronym(trimmed)
    }

    static func shouldIgnore(_ range: NSRange, in text: NSString, protected: [NSRange], settings: AppSettings) -> Bool {
        if protected.contains(where: { TextUnits.overlaps($0, range) }) { return true }
        guard let word = TextUnits.substring(text, range) else { return true }
        return isIgnorableWord(word, settings: settings)
    }

    static func looksLikeCode(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        if token.hasPrefix("@") || token.hasPrefix("#") { return token.count > 1 }
        if token.hasPrefix("."), token.count > 1 { return true }
        let scalars = Array(token.unicodeScalars)
        var previousWasLower = false
        for (index, scalar) in scalars.enumerated() {
            if CharacterSet.decimalDigits.contains(scalar) { return true }
            if scalar == "_" { return true }
            if Patterns.codeSymbols.contains(scalar) { return true }
            let isUpper = CharacterSet.uppercaseLetters.contains(scalar)
            if isUpper, previousWasLower { return true }
            previousWasLower = CharacterSet.lowercaseLetters.contains(scalar)
            if scalar == ".", index > 0, index < scalars.count - 1,
               CharacterSet.alphanumerics.contains(scalars[index - 1]),
               CharacterSet.alphanumerics.contains(scalars[index + 1]) {
                return true
            }
        }
        return token.contains("::") || token.contains("->") || token.contains("()")
    }

    static func isAcronym(_ word: String) -> Bool {
        let letters = word.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard letters.count >= 2 else { return false }
        if letters.allSatisfy({ CharacterSet.uppercaseLetters.contains($0) }) { return true }
        if letters.last == "s" {
            let stem = letters.dropLast()
            return stem.count >= 2 && stem.allSatisfy { CharacterSet.uppercaseLetters.contains($0) }
        }
        return false
    }

    static func trimmedToken(_ token: String) -> String {
        var scalars = token.unicodeScalars
        while let first = scalars.first, Patterns.leadingStrip.contains(first) { scalars.removeFirst() }
        while let last = scalars.last, Patterns.trailingStrip.contains(last) { scalars.removeLast() }
        return String(scalars)
    }

    private enum Patterns {
        // swiftlint:disable force_try
        static let all: [NSRegularExpression] = [
            try! NSRegularExpression(pattern: "```[\\s\\S]*?(?:```|\\z)"),
            try! NSRegularExpression(pattern: "`[^`\\n]+`"),
            try! NSRegularExpression(pattern: "\\b[A-Za-z][A-Za-z0-9+.-]*://[^\\s<>\"]+"),
            try! NSRegularExpression(pattern: "\\bwww\\.[^\\s<>\"]+"),
            try! NSRegularExpression(pattern: "[\\p{L}\\p{N}._%+-]+@[\\p{L}\\p{N}-]+(?:\\.[\\p{L}\\p{N}-]+)+"),
            try! NSRegularExpression(pattern: "(?<![\\p{L}\\p{N}_])[@#][\\p{L}\\p{N}_][\\p{L}\\p{N}_.-]*"),
        ]
        static let token = try! NSRegularExpression(pattern: "\\S+")
        // swiftlint:enable force_try
        static let links = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

        static let codeSymbols = CharacterSet(charactersIn: "/\\=<>{}[]|~^$%&*+")
        static let leadingStrip = CharacterSet(charactersIn: "\"'“”‘’«»„‚([{<*_~¿¡")
        static let trailingStrip = CharacterSet(charactersIn: "\"'“”‘’«»)]}>*_~.,;:!?…")
    }
}
