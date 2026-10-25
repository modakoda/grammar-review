import AppKit
import GrammarModels
import os

protocol SpellChecking: Sendable {
    func misspellings(in text: String, language: String?, resolver: LanguageResolver, settings: AppSettings) async -> [TextIssue]
    func learnWord(_ word: String)
}

final class LocalSpellChecker: SpellChecking {
    static let unitsPerHop = 4000
    static let maxIssues = 200
    static let maxGuesses = 3

    init() {}

    func misspellings(in text: String, language: String?, resolver: LanguageResolver, settings: AppSettings) async -> [TextIssue] {
        let paragraphs = ParagraphSplitter.split(text)
        guard !paragraphs.isEmpty else { return [] }

        let environment = await MainActor.run { SpellEnvironment.current() }
        let jobs: [SpellJob] = paragraphs.compactMap { paragraph in
            let paragraphLanguage = resolver.language(ofParagraph: paragraph.text, overall: language)
            switch SpellLanguage.resolve(paragraphLanguage, available: environment.available, current: environment.current) {
            case .unsupported: return nil
            case .systemDefault: return SpellJob(paragraph: paragraph, language: nil)
            case .specific(let code): return SpellJob(paragraph: paragraph, language: code)
            }
        }
        guard !jobs.isEmpty else { return [] }

        let protected = SpellingFilter.protectedRanges(in: text)
        var issues: [TextIssue] = []
        var batch: [SpellJob] = []
        var batchUnits = 0

        func flush() async {
            guard !batch.isEmpty else { return }
            let current = batch
            batch = []
            batchUnits = 0
            let found = await MainActor.run {
                SpellEnvironment.scan(current, tag: environment.tag) { range in
                    SpellingFilter.shouldIgnore(range, in: text as NSString, protected: protected, settings: settings)
                }
            }
            issues.append(contentsOf: found)
        }

        for job in jobs {
            if Task.isCancelled || issues.count >= Self.maxIssues { break }
            batch.append(job)
            batchUnits += job.paragraph.text.utf16.count
            if batchUnits >= Self.unitsPerHop { await flush() }
        }
        if !Task.isCancelled, issues.count < Self.maxIssues { await flush() }
        return Array(issues.prefix(Self.maxIssues))
    }

    func learnWord(_ word: String) {
        let word = word.trimmedWhitespace
        guard !word.isEmpty else { return }
        if Thread.isMainThread {
            MainActor.assumeIsolated { NSSpellChecker.shared.learnWord(word) }
        } else {
            Task { @MainActor in NSSpellChecker.shared.learnWord(word) }
        }
    }
}
