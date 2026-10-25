import Foundation

struct HarperLint: Sendable, Equatable {
    var range: NSRange
    var rule: String?
    var kind: String?
    var message: String
    var replacements: [String]

    init(range: NSRange, rule: String? = nil, kind: String?, message: String, replacements: [String]) {
        self.range = range
        self.rule = rule
        self.kind = kind
        self.message = message
        self.replacements = replacements
    }

    init?(diagnostic: LSPDiagnostic, actions: [LSPCodeAction], uri: String, lines: LSPLineIndex, text: NSString) {
        guard let base = lines.utf16Range(of: diagnostic.range), NSMaxRange(base) <= text.length else { return nil }
        let actions = LSPCodeAction.actions(for: diagnostic, in: actions)
        let fixes: [[NSRange: String]] = actions.compactMap { action in
            var edits: [NSRange: String] = [:]
            for edit in action.edits[uri] ?? [] {
                guard let range = lines.utf16Range(of: edit.range) else { return nil }
                edits[range] = edit.newText
            }
            return edits.isEmpty ? nil : edits
        }
        let covered = fixes.flatMap(\.keys).reduce(base) { NSUnionRange($0, $1) }
        guard NSMaxRange(covered) <= text.length else { return nil }
        let original = text.substring(with: covered)
        var seen = Set<String>()
        let replacements = fixes.compactMap { edits -> String? in
            let fixed = NSMutableString(string: original)
            for (range, newText) in edits.sorted(by: { $0.key.location > $1.key.location }) {
                let local = NSRange(location: range.location - covered.location, length: range.length)
                guard NSMaxRange(local) <= fixed.length else { return nil }
                fixed.replaceCharacters(in: local, with: newText)
            }
            let result = fixed as String
            return result != original && seen.insert(result).inserted ? result : nil
        }
        self.init(
            range: covered,
            rule: diagnostic.code,
            kind: actions.lazy.compactMap(\.lintKind).first,
            message: diagnostic.message,
            replacements: replacements
        )
    }
}

enum HarperDialect: String, Sendable, CaseIterable {
    case american = "American"
    case british = "British"
    case australian = "Australian"
    case canadian = "Canadian"
    case indian = "Indian"

    init(language: String?, preferredLanguages: [String]) {
        let english = ([language].compactMap(\.self) + preferredLanguages).filter(SpellingVariantConsistency.isEnglish)
        guard let region = english.lazy.compactMap(Self.region(of:)).first else {
            self = .american
            return
        }
        switch region {
        case "US", "PH", "PR": self = .american
        case "AU", "NZ": self = .australian
        case "CA": self = .canadian
        case "IN": self = .indian
        default: self = .british
        }
    }

    private static func region(of language: String) -> String? {
        language.split(whereSeparator: { $0 == "-" || $0 == "_" })
            .dropFirst()
            .first { $0.count == 2 && $0.allSatisfy(\.isLetter) }
            .map { $0.uppercased() }
    }
}

struct HarperConfiguration: Sendable, Equatable {
    // macOS checks spelling in every language; the editor highlights long sentences itself.
    static let disabledLinters = ["SpellCheck", "LongSentences"]

    var dialect: HarperDialect

    var settings: JSONValue {
        .object([("harper-ls", .object([
            ("dialect", .string(dialect.rawValue)),
            ("diagnosticSeverity", .string("hint")),
            ("linters", .object(Self.disabledLinters.map { ($0, .bool(false)) })),
        ]))])
    }
}
