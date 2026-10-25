import Foundation
import GrammarModels
import os
import Testing
@testable import GrammarEngine

final class MockHarperLinter: HarperLinting {
    struct Call: Equatable {
        var text: String
        var dialect: HarperDialect
        var executable: String
    }

    private let calls = OSAllocatedUnfairLock<[Call]>(initialState: [])
    private let handler: @Sendable (String) async throws -> [HarperLint]

    init(handler: @escaping @Sendable (String) async throws -> [HarperLint] = { _ in [] }) {
        self.handler = handler
    }

    var received: [Call] { calls.withLock { $0 } }

    func lint(_ text: String, configuration: HarperConfiguration, executable: String) async throws -> [HarperLint] {
        calls.withLock { $0.append(Call(text: text, dialect: configuration.dialect, executable: executable)) }
        return try await handler(text)
    }
}

func harperLint(_ text: String, _ target: String, _ replacements: [String], kind: String? = "Grammar", message: String = "m") -> HarperLint {
    HarperLint(range: (text as NSString).range(of: target), kind: kind, message: message, replacements: replacements)
}

@Suite struct HarperLocatorTests {
    private func locator(_ executables: Set<String>, path: String = "") -> HarperLocator {
        HarperLocator(environment: ["PATH": path], home: "/Users/me", isExecutable: { executables.contains($0) })
    }

    @Test func aChosenFileOrFolderWins() {
        let found = locator(["/opt/homebrew/bin/harper-ls", "/Users/me/tools/harper-ls"])
        #expect(found.locate(customPath: "~/tools/harper-ls") == .found("/Users/me/tools/harper-ls"))
        #expect(found.locate(customPath: " ~/tools ") == .found("/Users/me/tools/harper-ls"))
        #expect(found.locate(customPath: "/nowhere/harper-ls") == .invalid("/nowhere/harper-ls"))
    }

    @Test func otherwiseThePathThenTheUsualFolders() {
        #expect(locator(["/usr/local/bin/harper-ls", "/custom/bin/harper-ls"], path: "/usr/bin:/custom/bin")
            .locate(customPath: "") == .found("/custom/bin/harper-ls"))
        #expect(locator(["/usr/local/bin/harper-ls", "/Users/me/.cargo/bin/harper-ls"])
            .locate(customPath: "") == .found("/usr/local/bin/harper-ls"))
        #expect(locator(["/Users/me/.cargo/bin/harper-ls"]).locate(customPath: "") == .found("/Users/me/.cargo/bin/harper-ls"))
        #expect(locator([]).locate(customPath: "") == .missing)
    }

    @Test func directoriesAreNotPrograms() {
        #expect(!HarperLocator.isExecutableFile("/usr/bin"))
        #expect(HarperLocator.isExecutableFile("/bin/sh"))
    }

    @Test func versionsAreReadFromTheOutput() {
        #expect(HarperProbe.version(fromOutput: "harper-ls 2.13.0\n") == "2.13.0")
        #expect(HarperProbe.version(fromOutput: "") == "unknown")
    }
}

@Suite struct HarperCheckerTests {
    private func issues(_ text: String, _ lints: [HarperLint], english: [NSRange]? = nil, found: [TextIssue] = []) -> [TextIssue] {
        let everything = [NSRange(location: 0, length: (text as NSString).length)]
        return HarperChecker.issues(from: lints, in: text, english: english ?? everything, excluding: found)
    }

    @Test func lintsBecomeLocalIssuesInTheirCategory() {
        let text = "This is an test. Its fine."
        let found = issues(text, [
            harperLint(text, "an", ["a"], kind: "Miscellaneous", message: "Incorrect indefinite article."),
            harperLint(text, "Its", ["It's", "It has"], kind: "Punctuation", message: "Use `it's` here, not the possessive `its`."),
        ])
        #expect(found.map(\.originalText) == ["an", "Its"])
        #expect(found.map(\.category) == [.grammar, .punctuation])
        #expect(found.allSatisfy { $0.source == .local })
        #expect(found[1].replacements == ["It's", "It has"])
        #expect(found[1].message == "Use “it's” here, not the possessive “its”.")
    }

    @Test func everyKindHasACategory() {
        #expect(HarperChecker.category(forKind: "Typo") == .spelling)
        #expect(HarperChecker.category(forKind: "Formatting") == .punctuation)
        #expect(HarperChecker.category(forKind: "WordChoice") == .wordChoice)
        #expect(HarperChecker.category(forKind: "Redundancy") == .clarity)
        #expect(HarperChecker.category(forKind: "Enhancement") == .style)
        #expect(HarperChecker.category(forKind: "Agreement") == .grammar)
        #expect(HarperChecker.category(forKind: nil) == .grammar)
    }

    @Test func onlyEnglishParagraphsAndPlainTextAreChecked() {
        let text = "Labas rytas, kaip sekasi?\nSee https://example.com/an-test for an test."
        let english = [NSRange(location: 26, length: (text as NSString).length - 26)]
        let lints = [
            harperLint(text, "kaip", ["kap"]),
            harperLint(text, "an-test", ["a-test"]),
            harperLint(text, "an test.", ["a test."]),
        ]
        #expect(issues(text, lints, english: english).map(\.originalText) == ["an test."])
    }

    @Test func otherLocalIssuesWinOverlaps() {
        let text = "Teh the cat sat."
        let spelling = issue(0, "Teh")
        let lints = [harperLint(text, "Teh the", ["The"]), harperLint(text, "cat", ["cats"]), harperLint(text, "cat sat", ["cat sits"])]
        #expect(issues(text, lints, found: [spelling]).map(\.originalText) == ["cat"])
    }

    @Test func whitespaceFixesShowTheirNeighbours() {
        let text = "A good idea , and.  Next"
        let lints = [
            HarperLint(range: NSRange(location: 11, length: 1), kind: "Punctuation", message: "Don't use a space before a comma.", replacements: [""]),
            HarperLint(range: NSRange(location: 18, length: 2), kind: "Formatting", message: "French spaces.", replacements: [" "]),
        ]
        let found = issues(text, lints)
        #expect(found.map(\.originalText) == ["idea ,", "and.  Next"])
        #expect(found.map(\.replacements) == [["idea,"], ["and. Next"]])
    }

    @Test func aWhitespaceFixNextToAnotherIssueStaysNarrow() {
        let text = "Teh , and"
        let lint = HarperLint(range: NSRange(location: 3, length: 1), kind: "Punctuation", message: "m", replacements: [""])
        let found = issues(text, [lint], found: [issue(0, "Teh")])
        #expect(found.map(\.originalText) == [" "])
        #expect(found.map(\.replacements) == [[""]])
    }

    @Test func repeatedAndUnchangedReplacementsAreDropped() {
        let text = "Their going."
        let found = issues(text, [harperLint(text, "Their", ["They're", "They're ", "Their", "There", "They are", "Thy"])])
        #expect(found.first?.replacements == ["They're", "There", "They are"])
    }

    @Test func runsOnlyWhenOnAndEnglishAndInstalled() async {
        let linter = MockHarperLinter { text in [harperLint(text, "an", ["a"])] }
        let installed = HarperLocator(environment: [:], home: "/Users/me", isExecutable: { $0 == "/opt/homebrew/bin/harper-ls" })
        let checker = HarperChecker(linter: linter, locator: installed)
        let english = LanguageResolver(mode: .fixed("en-GB"))

        let found = await checker.issues(in: "This is an test.", language: "en-GB", resolver: english, settings: AppSettings(), excluding: [])
        #expect(found.map(\.replacements) == [["a"]])
        #expect(linter.received == [.init(text: "This is an test.", dialect: .british, executable: "/opt/homebrew/bin/harper-ls")])

        var off = AppSettings()
        off.harperEnabled = false
        #expect(await checker.issues(in: "This is an test.", language: "en", resolver: english, settings: off, excluding: []).isEmpty)
        let lithuanian = LanguageResolver(mode: .fixed("lt"))
        #expect(await checker.issues(in: "Tai yra testas.", language: "lt", resolver: lithuanian, settings: AppSettings(), excluding: []).isEmpty)
        let missing = HarperChecker(linter: linter, locator: HarperLocator(environment: [:], home: "/Users/me", isExecutable: { _ in false }))
        #expect(await missing.issues(in: "This is an test.", language: "en", resolver: english, settings: AppSettings(), excluding: []).isEmpty)
        #expect(linter.received.count == 1)
    }

    @Test func aFailingLinterLeavesTheOtherChecksAlone() async {
        let checker = HarperChecker(
            linter: MockHarperLinter { _ in throw HarperError.timedOut },
            locator: HarperLocator(environment: [:], home: "/Users/me", isExecutable: { _ in true })
        )
        let found = await checker.issues(in: "This is an test.", language: "en", resolver: LanguageResolver(mode: .fixed("en")),
                                         settings: AppSettings(), excluding: [])
        #expect(found.isEmpty)
    }
}
