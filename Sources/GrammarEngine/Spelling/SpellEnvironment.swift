import AppKit
import GrammarModels
import os

struct SpellJob: Sendable {
    var paragraph: Paragraph
    var language: String?
}

struct SpellEnvironmentSnapshot: Sendable {
    var available: [String]
    var current: String?
    var tag: Int
}

@MainActor
enum SpellEnvironment {
    private static var documentTag: Int?

    static func current() -> SpellEnvironmentSnapshot {
        let checker = NSSpellChecker.shared
        let tag = documentTag ?? NSSpellChecker.uniqueSpellDocumentTag()
        documentTag = tag
        let current = checker.language()
        return SpellEnvironmentSnapshot(available: checker.availableLanguages, current: current.isEmpty ? nil : current, tag: tag)
    }

    static func scan(_ jobs: [SpellJob], tag: Int, shouldIgnore: (NSRange) -> Bool) -> [TextIssue] {
        let checker = NSSpellChecker.shared
        var issues: [TextIssue] = []
        for job in jobs {
            let text = job.paragraph.text
            let paragraph = text as NSString
            var offset = 0
            while offset < paragraph.length {
                let found = checker.checkSpelling(
                    of: text, startingAt: offset, language: job.language,
                    wrap: false, inSpellDocumentWithTag: tag, wordCount: nil
                )
                guard found.location != NSNotFound, found.length > 0, found.location >= offset else { break }
                offset = NSMaxRange(found)
                let fullRange = NSRange(location: found.location + job.paragraph.location, length: found.length)
                if shouldIgnore(fullRange) { continue }
                let word = paragraph.substring(with: found)
                let guesses = checker.guesses(forWordRange: found, in: text, language: job.language, inSpellDocumentWithTag: tag) ?? []
                issues.append(TextIssue(
                    range: fullRange,
                    originalText: word,
                    replacements: Array(IssueMerger.deduplicated(guesses.filter { $0 != word }).prefix(LocalSpellChecker.maxGuesses)),
                    message: guesses.isEmpty ? "Unknown word." : "Possible spelling mistake.",
                    category: .spelling,
                    source: .local
                ))
                if issues.count >= LocalSpellChecker.maxIssues { return issues }
            }
        }
        return issues
    }
}
