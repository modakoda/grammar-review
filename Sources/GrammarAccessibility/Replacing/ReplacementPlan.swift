import Foundation

nonisolated struct ReplacementPlan: Equatable, Sendable {
    let range: NSRange
    let replacement: String
    let originalText: String
    let expectedText: String

    var caretAfter: NSRange {
        NSRange(location: range.location + (replacement as NSString).length, length: 0)
    }

    init?(text: String, range: NSRange, replacement: String) {
        let nsText = text as NSString
        guard Self.isValid(range, in: nsText) else { return nil }
        self.range = range
        self.replacement = replacement
        self.originalText = text
        self.expectedText = nsText.replacingCharacters(in: range, with: replacement)
    }

    static func isValid(_ range: NSRange, in text: NSString) -> Bool {
        guard range.location != NSNotFound, range.location >= 0, range.length >= 0,
              range.location <= text.length, range.length <= text.length - range.location
        else { return false }
        return !splitsSurrogatePair(at: range.location, in: text)
            && !splitsSurrogatePair(at: NSMaxRange(range), in: text)
    }

    static func splitsSurrogatePair(at index: Int, in text: NSString) -> Bool {
        guard index > 0, index < text.length else { return false }
        return UTF16.isLeadSurrogate(text.character(at: index - 1)) && UTF16.isTrailSurrogate(text.character(at: index))
    }

    func outcome(for actual: String?) -> ReplacementOutcome {
        guard let actual else { return .unreadable }
        let normalized = TextNormalization.normalized(actual)
        if normalized == TextNormalization.normalized(expectedText) { return .applied }
        if normalized == TextNormalization.normalized(originalText) { return .unchanged }
        return .diverged
    }
}

nonisolated enum ReplacementOutcome: Equatable, Sendable {
    case applied
    case unchanged
    case diverged
    case unreadable
}

nonisolated enum TextNormalization {
    static func normalized(_ text: String) -> String {
        guard text.contains(where: { $0 == "\r\n" || $0 == "\r" || $0 == "\u{00A0}" }) else { return text }
        return text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }
}
