import Foundation
import GrammarModels
import os

struct HarperChecker: Sendable {
    static let maxUTF8Length = 100_000
    static let maxReplacements = 3
    static let maxWidening = 40

    let linter: (any HarperLinting)?
    var locator = HarperLocator()

    func issues(
        in text: String,
        language: String?,
        resolver: LanguageResolver,
        settings: AppSettings,
        excluding found: [TextIssue]
    ) async -> [TextIssue] {
        guard let linter, settings.harperEnabled, text.utf8.count <= Self.maxUTF8Length else { return [] }
        let english = ParagraphSplitter.split(text)
            .filter { resolver.language(ofParagraph: $0.text, overall: language).map(SpellingVariantConsistency.isEnglish) ?? false }
            .map(\.range)
        guard !english.isEmpty, case .found(let executable) = locator.locate(customPath: settings.harperPath) else { return [] }
        let configuration = HarperConfiguration(dialect: HarperDialect(language: language, preferredLanguages: resolver.preferredLanguages))
        do {
            let lints = try await linter.lint(text, configuration: configuration, executable: executable)
            guard !Task.isCancelled else { return [] }
            return Self.issues(from: lints, in: text, english: english, excluding: found)
        } catch {
            if !(error is CancellationError) {
                Log.engine.debug("Harper: no offline grammar for this check (\(String(describing: error), privacy: .public))")
            }
            return []
        }
    }

    static func issues(from lints: [HarperLint], in text: String, english: [NSRange], excluding found: [TextIssue]) -> [TextIssue] {
        let ns = text as NSString
        var blocked = SpellingFilter.protectedRanges(in: text) + found.map(\.range)
        var issues: [TextIssue] = []
        for lint in lints {
            guard lint.range.length > 0, NSMaxRange(lint.range) <= ns.length,
                  english.contains(where: { NSIntersectionRange($0, lint.range) == lint.range }),
                  !blocked.contains(where: { TextUnits.overlaps($0, lint.range) }) else { continue }
            var (range, replacements) = (lint.range, lint.replacements)
            let widened = widened(lint, in: ns)
            if widened.range != range, !blocked.contains(where: { TextUnits.overlaps($0, widened.range) }) {
                (range, replacements) = widened
            }
            let original = ns.substring(with: range)
            blocked.append(range)
            issues.append(TextIssue(
                range: range,
                originalText: original,
                replacements: Array(distinct(replacements, excluding: original).prefix(maxReplacements)),
                message: quoted(lint.message),
                category: category(forKind: lint.kind),
                source: .local
            ))
        }
        return issues
    }

    static func category(forKind kind: String?) -> IssueCategory {
        switch kind {
        case "Spelling", "Typo": .spelling
        case "Punctuation", "Formatting": .punctuation
        case "WordChoice", "Usage", "Regionalism": .wordChoice
        case "Readability", "Redundancy": .clarity
        case "Style", "Enhancement": .style
        default: .grammar
        }
    }

    static func quoted(_ message: String) -> String {
        Patterns.code.stringByReplacingMatches(
            in: message,
            range: NSRange(location: 0, length: (message as NSString).length),
            withTemplate: "\u{201C}$1\u{201D}"
        )
    }

    static func widened(_ lint: HarperLint, in text: NSString) -> (range: NSRange, replacements: [String]) {
        guard text.substring(with: lint.range).trimmedWhitespace.isEmpty else { return (lint.range, lint.replacements) }
        let start = boundary(from: lint.range.location, backwards: true, in: text)
        let end = boundary(from: NSMaxRange(lint.range), backwards: false, in: text)
        let range = NSRange(location: start, length: end - start)
        guard range != lint.range, text.rangeOfComposedCharacterSequences(for: range) == range else { return (lint.range, lint.replacements) }
        let before = text.substring(with: NSRange(location: start, length: lint.range.location - start))
        let after = text.substring(with: NSRange(location: NSMaxRange(lint.range), length: end - NSMaxRange(lint.range)))
        return (range, lint.replacements.map { before + $0 + after })
    }

    private static func boundary(from start: Int, backwards: Bool, in text: NSString) -> Int {
        var index = start
        for _ in 0..<maxWidening {
            let next = backwards ? index - 1 : index
            guard next >= 0, next < text.length,
                  let scalar = Unicode.Scalar(text.character(at: next)),
                  !CharacterSet.whitespacesAndNewlines.contains(scalar) else { break }
            index += backwards ? -1 : 1
        }
        return index
    }

    private static func distinct(_ replacements: [String], excluding original: String) -> [String] {
        var seen = Set<String>()
        return replacements.filter { replacement in
            replacement != original && seen.insert(replacement.trimmedWhitespace).inserted
        }
    }

    private enum Patterns {
        // swiftlint:disable:next force_try
        static let code = try! NSRegularExpression(pattern: "`([^`\\n]+)`")
    }
}
