import Foundation
import GrammarEngine
import GrammarModels
import os
import Testing
@testable import GrammarEditor

@MainActor
@Suite(.timeLimit(.minutes(1))) struct EditorModelTests {
    @Test func typingChecksTheTextWithTheChosenStyle() async throws {
        let harness = Harness(style: .formal)
        harness.type("I has teh cat.")
        try await waitUntil { harness.model.issues.count == 2 }

        #expect(harness.model.issues.map(\.originalText) == ["has", "teh"])
        #expect(harness.checker.requests.last?.goals.style == .formal)
        #expect(harness.model.status == .idle)
        #expect(harness.surface.decorations.last?.underlines.map(\.severity) == [.correctness, .correctness])
    }

    @Test func choosingAStyleSavesItAndRechecks() async throws {
        let harness = Harness()
        harness.type("I has a cat.")
        try await waitUntil { harness.checker.requests.count == 1 }

        harness.model.setStyle(.concise)
        try await waitUntil { harness.checker.requests.count == 2 }
        #expect(harness.checker.requests.last?.goals.style == .concise)
        #expect(harness.savedGoals == [WritingGoals(style: .concise)])

        let goals = WritingGoals(style: .concise, audience: .expert, domain: .technical)
        harness.model.setGoals(goals)
        try await waitUntil { harness.checker.requests.count == 3 }
        #expect(harness.checker.requests.last?.goals == goals)
        harness.model.setGoals(goals)
        #expect(harness.savedGoals.count == 2, "setting the same goals again does nothing")
    }

    @Test func acceptingAFixEditsTheTextThroughTheView() async throws {
        let harness = Harness()
        harness.type("I has teh cat.")
        try await waitUntil { harness.model.issues.count == 2 }

        let teh = try #require(harness.model.issues.first { $0.originalText == "teh" })
        #expect(harness.model.accept("the", for: teh))
        #expect(harness.surface.text == "I has the cat.")
        #expect(harness.model.text == "I has the cat.")
        #expect(harness.model.issues.map(\.originalText) == ["has"])
        #expect(!harness.model.isTyping)
    }

    @Test func acceptAllFixesCorrectnessOnly() async throws {
        let harness = Harness()
        harness.type("I has teh cat, which is very unique.")
        try await waitUntil { harness.model.issues.count == 3 }

        #expect(harness.model.acceptAllCount == 2)
        harness.model.acceptAll()
        #expect(harness.surface.text == "I have the cat, which is very unique.")
        #expect(harness.model.issues.map(\.originalText) == ["very unique"])
    }

    @Test func ignoredSuggestionsStayHiddenAfterARecheck() async throws {
        let harness = Harness()
        harness.type("I has a cat.")
        try await waitUntil { harness.model.issues.count == 1 }

        harness.model.ignore(harness.model.issues[0])
        #expect(harness.model.issues.isEmpty)
        #expect(harness.model.ignoredIssues.map(\.originalText) == ["has"])
        harness.type("I has a cat!")
        try await waitUntil { harness.checker.requests.count == 2 && !harness.model.isChecking }
        #expect(harness.model.issues.isEmpty)
        #expect(harness.model.ignoredIssues.map(\.originalText) == ["has"])
    }

    @Test func restoringAnIgnoredSuggestionShowsItAgain() async throws {
        let harness = Harness()
        harness.type("I has teh cat.")
        try await waitUntil { harness.model.issues.count == 2 }

        harness.model.ignore(harness.model.issues[0])
        #expect(harness.model.issues.map(\.originalText) == ["teh"])
        #expect(harness.surface.decorations.last?.underlines.map(\.range) == [NSRange(location: 6, length: 3)])

        harness.type("Now I has teh cat.")
        let ignored = try #require(harness.model.ignoredIssues.first)
        #expect(ignored.range == NSRange(location: 6, length: 3))
        harness.model.restore(ignored)
        #expect(harness.model.ignoredIssues.isEmpty)
        #expect(harness.model.issues.map(\.originalText) == ["has", "teh"])
        #expect(harness.surface.decorations.last?.underlines.map(\.range.location) == [6, 10])

        try await waitUntil { harness.checker.requests.count == 2 && !harness.model.isChecking }
        #expect(harness.model.issues.map(\.originalText) == ["has", "teh"])
    }

    @Test func aRecheckKeepsTheSameSuggestionsIdentity() async throws {
        let harness = Harness()
        harness.type("I has a cat.")
        try await waitUntil { harness.model.issues.count == 1 }
        let id = harness.model.issues[0].id
        harness.model.select(harness.model.issues[0])

        harness.type("I has a cat. More")
        try await waitUntil { harness.checker.requests.count == 2 && !harness.model.isChecking }
        #expect(harness.model.issues.map(\.id) == [id])
        #expect(harness.model.selectedIssueID == id)
        #expect(harness.surface.revealed == [NSRange(location: 2, length: 3)])
    }

    @Test func filterAndCountsFollowSeverity() async throws {
        let harness = Harness()
        harness.type("I has teh cat, which is very unique.")
        try await waitUntil { harness.model.issues.count == 3 }

        #expect(harness.model.count(of: nil) == 3)
        #expect(harness.model.count(of: .correctness) == 2)
        #expect(harness.model.count(of: .style) == 1)
        harness.model.filter = .style
        #expect(harness.model.filteredIssues.map(\.originalText) == ["very unique"])
    }

    @Test func movingTheCaretIntoAnUnderlineSelectsItsCard() async throws {
        let harness = Harness()
        harness.type("I has teh cat.")
        try await waitUntil { harness.model.issues.count == 2 && !harness.model.isTyping }

        harness.model.selectionDidChange(NSRange(location: 7, length: 0), in: harness.surface.text)
        #expect(harness.model.selectedIssueID == harness.model.issues.first { $0.originalText == "teh" }?.id)
        #expect(harness.surface.decorations.last?.active == NSRange(location: 6, length: 3))

        harness.model.selectionDidChange(NSRange(location: 0, length: 0), in: harness.surface.text)
        #expect(harness.model.selectedIssueID == nil)
    }

    @Test func aMisspellingAtTheCaretIsHiddenWhileTyping() async throws {
        let harness = Harness(typingSettle: .seconds(30))
        harness.type("I like teh", caret: 10)
        try await waitUntil { harness.model.issues.count == 1 }

        #expect(harness.model.visibleIssues.isEmpty)
        #expect(harness.surface.decorations.last?.underlines.isEmpty == true)
    }

    @Test func rewriteReplacesTheParagraphAtTheCaret() async throws {
        let harness = Harness()
        harness.type("First paragraph.\nSecond one here.\n", caret: 20)
        harness.model.startRewrite(.formal)

        #expect(harness.model.rewrite?.original == "Second one here.")
        #expect(harness.model.rewrite?.scope == .paragraph)
        #expect(harness.surface.decorations.last?.rewriteTarget == NSRange(location: 17, length: 16))
        try await waitUntil { harness.model.rewrite?.result == .ready("[formal] Second one here.") }

        harness.model.applyRewrite()
        #expect(harness.surface.text == "First paragraph.\n[formal] Second one here.\n")
        #expect(harness.model.rewrite == nil)
    }

    @Test func rephrasesTheSentenceAtTheCaret() async throws {
        let harness = Harness()
        harness.type("First one. Second one here. Third.", caret: 15)
        harness.model.rephraseSentence()

        #expect(harness.model.rewrite?.original == "Second one here.")
        #expect(harness.model.rewrite?.scope == .sentence)
        #expect(harness.model.rewrite?.goal == .tone(.rephrase))
        #expect(harness.surface.decorations.last?.rewriteTarget == NSRange(location: 11, length: 16))
        try await waitUntil { harness.model.rewrite?.result == .ready("[rephrase] Second one here.") }

        harness.model.changeRewriteTone(.friendly)
        try await waitUntil { harness.model.rewrite?.result == .ready("[friendly] Second one here.") }
        harness.model.applyRewrite()
        #expect(harness.surface.text == "First one. [friendly] Second one here. Third.")
        #expect(harness.rewriter.tones == [.rephrase, .friendly])
    }

    @Test func rephrasesTheSentenceOfASuggestion() async throws {
        let harness = Harness()
        harness.type("All good here. I like teh cat. The end.", caret: 0)
        try await waitUntil { harness.model.issues.count == 1 }

        harness.model.rephraseSentence(of: harness.model.issues[0])
        #expect(harness.model.rewrite?.original == "I like teh cat.")
        #expect(harness.model.rewrite?.scope == .sentence)
        try await waitUntil { harness.model.rewrite?.result == .ready("[rephrase] I like teh cat.") }
    }

    @Test func rephrasingNothingBeeps() {
        let harness = Harness()
        harness.type("Text.\n\n")
        harness.model.rephraseSentence()
        #expect(harness.model.rewrite == nil)
    }

    @Test func rephrasingIsOfferedOnlyWithAI() async throws {
        let on = Harness()
        on.type("Fine text.")
        try await waitUntil { !on.model.isChecking }
        #expect(on.model.offersRephrase)

        let off = Harness(aiStatus: .disabled, aiEnabled: false)
        off.type("Fine text.")
        try await waitUntil { !off.model.isChecking }
        #expect(!off.model.offersRephrase)
    }

    @Test func rewriteReplacesTheSelection() async throws {
        let harness = Harness()
        harness.type("Hello there, friend.", selection: NSRange(location: 0, length: 11))
        #expect(harness.model.rewritesSelection)
        harness.model.startRewrite(.formal)
        #expect(harness.model.rewrite?.scope == .selection)
        try await waitUntil { harness.model.rewrite?.result == .ready("[formal] Hello there") }

        harness.model.applyRewrite()
        #expect(harness.surface.text == "[formal] Hello there, friend.")
    }

    @Test func cancellingARewriteOrADraftClearsItsCard() {
        let harness = Harness()
        harness.type("Some text here.", selection: NSRange(location: 0, length: 4))
        harness.model.startRewrite(.formal)
        #expect(harness.surface.decorations.last?.rewriteTarget == NSRange(location: 0, length: 4))
        harness.model.cancelRewrite()
        #expect(harness.model.rewrite == nil)
        #expect(harness.surface.decorations.last?.rewriteTarget == nil)

        harness.model.startCompose()
        #expect(harness.surface.decorations.last?.rewriteTarget == NSRange(location: 0, length: 4))
        harness.model.cancelCompose()
        #expect(harness.model.compose == nil)
        #expect(harness.surface.decorations.last?.rewriteTarget == nil)
        #expect(harness.surface.text == "Some text here.")
    }

    @Test func aFixForTextThatChangedIsNotApplied() async throws {
        let harness = Harness()
        harness.type("I like teh cat.")
        try await waitUntil { harness.model.issues.count == 1 }
        let teh = harness.model.issues[0]

        harness.type("I like tea cat.")
        #expect(!harness.model.accept("the", for: teh))
        #expect(harness.surface.text == "I like tea cat.")
    }

    @Test func rewriteIsNotAppliedWhenTheTextChanged() async throws {
        let harness = Harness()
        harness.type("Old words.")
        harness.model.startRewrite(.concise)
        try await waitUntil {
            if case .ready = harness.model.rewrite?.result { true } else { false }
        }

        harness.type("New words.")
        harness.model.applyRewrite()
        #expect(harness.surface.text == "New words.")
        guard case .failed = harness.model.rewrite?.result else {
            Issue.record("expected a failure message")
            return
        }
    }

    @Test func addingToTheDictionaryLearnsTheWord() async throws {
        let harness = Harness()
        harness.type("I like teh cat.")
        try await waitUntil { harness.model.issues.count == 1 }

        harness.model.addToDictionary(harness.model.issues[0])
        #expect(harness.model.issues.isEmpty)
        #expect(harness.checker.learned == ["teh"])
        #expect(harness.dictionary == ["teh"])
    }

    @Test func missingAPIKeyIsShownWithASettingsButton() async throws {
        let harness = Harness(aiStatus: .missingAPIKey)
        harness.type("Fine text.")
        try await waitUntil { !harness.model.isChecking }
        guard case .notice(_, let offersSettings) = harness.model.status else {
            Issue.record("expected a notice")
            return
        }
        #expect(offersSettings)
    }

    @Test func wordCount() {
        let harness = Harness()
        harness.type("One two  three,\nfour.")
        #expect(harness.model.wordCount == 4)
    }

    @Test func aCustomRewriteWaitsForTheInstruction() async throws {
        let harness = Harness()
        harness.type("We shipped it.")
        harness.model.startCustomRewrite()
        #expect(harness.model.rewrite?.goal == .instruction(""))
        #expect(harness.model.rewrite?.result == nil)

        harness.model.rewrite(withInstruction: "  ")
        #expect(harness.model.rewrite?.result == nil, "a blank instruction does nothing")

        harness.model.rewrite(withInstruction: " Sound excited ")
        try await waitUntil { harness.model.rewrite?.result == .ready("[Sound excited] We shipped it.") }
        harness.model.applyRewrite()
        #expect(harness.surface.text == "[Sound excited] We shipped it.")
    }

    @Test func aToneAfterAnInstructionRewritesAgain() async throws {
        let harness = Harness()
        harness.type("We shipped it.")
        harness.model.startCustomRewrite()
        harness.model.rewrite(withInstruction: "Shorter")
        try await waitUntil { harness.model.rewrite?.result == .ready("[Shorter] We shipped it.") }
        harness.model.changeRewriteTone(.formal)
        #expect(harness.model.rewrite?.goal.tone == .formal)
        try await waitUntil { harness.model.rewrite?.result == .ready("[formal] We shipped it.") }
    }

    @Test func statisticsFollowTheTextAndLanguage() async throws {
        let harness = Harness()
        harness.type("The cat sat on the mat. It was a big cat. The dog ran to it.")
        #expect(harness.model.statistics.words == 16)
        #expect(harness.model.statistics.readingEase == nil, "the language isn't known before the first check")
        try await waitUntil { harness.model.language == "en" }
        #expect(harness.model.statistics.readingEase != nil)
    }

    @Test func longSentencesAreMarkedOnlyOnTheInsightsTab() {
        let harness = Harness()
        let long = (["Every"] + Array(repeating: "word", count: 30)).joined(separator: " ") + "."
        harness.type("Short. " + long)
        #expect(harness.surface.decorations.last?.longSentences.isEmpty == true)

        harness.model.sidebarTab = .insights
        #expect(harness.surface.decorations.last?.longSentences == [NSRange(location: 7, length: (long as NSString).length)])
        harness.model.revealLongSentence(at: 0)
        #expect(harness.surface.revealed.last?.location == 7)

        harness.model.sidebarTab = .suggestions
        #expect(harness.surface.decorations.last?.longSentences.isEmpty == true)
    }

    @Test func toneIsDetectedWhenInsightsAreShownAndAfterEdits() async throws {
        let harness = Harness()
        harness.type("We are happy to share the news today.")
        try await Task.sleep(for: .milliseconds(20))
        #expect(harness.toneDetector.texts.isEmpty, "nothing is sent while the Insights tab is closed")

        harness.model.sidebarTab = .insights
        try await waitUntil { harness.model.tone.isReady }
        #expect(harness.model.tone == .ready(ToneReport(tones: [ToneScore(tone: .neutral, intensity: .moderate)], sentiment: .positive, summary: "Fine.")))
        #expect(!harness.model.isDetectingTone)

        harness.type("We are happy to share the news today!")
        try await waitUntil { harness.toneDetector.texts.count == 2 && !harness.model.isDetectingTone }
        if case .ready(let report) = harness.model.tone {
            #expect(report.tones.first?.tone == .enthusiastic)
        } else {
            Issue.record("expected a tone report")
        }

        harness.model.sidebarTab = .suggestions
        harness.model.sidebarTab = .insights
        try await Task.sleep(for: .milliseconds(20))
        #expect(harness.toneDetector.texts.count == 2)
    }

    @Test func aToneFailureOffersSettingsAndIsRetried() async throws {
        let harness = Harness()
        harness.toneDetector.failure.withLock { $0 = .missingAPIKey }
        harness.type("We are happy to share the news today.")
        harness.model.sidebarTab = .insights
        try await waitUntil { !harness.model.isDetectingTone && harness.toneDetector.texts.count == 1 }
        #expect(harness.model.tone == .failed("Add an Anthropic API key in Settings to use tone detection.", offersSettings: true))

        harness.toneDetector.failure.withLock { $0 = nil }
        harness.model.settingsDidChange()
        try await waitUntil { harness.model.tone.isReady }
    }
}

extension EditorModelTests {
    @Test func composeInsertsAtTheCaretAsItsOwnParagraph() async throws {
        let harness = Harness()
        harness.type("Hi Ann,\nThanks for the invite.", caret: 7)
        harness.model.startCompose()
        #expect(harness.model.compose?.usesText == true)
        #expect(harness.model.compose?.result == nil)

        harness.model.compose("  a polite decline ")
        try await waitUntil { harness.model.compose?.result == .ready("<a polite decline>") }
        #expect(harness.composer.calls.first?.context == "Hi Ann,\nThanks for the invite.")

        harness.model.insertComposed()
        #expect(harness.surface.text == "Hi Ann,\n\n<a polite decline>\n\nThanks for the invite.")
        #expect(harness.model.compose == nil)
    }

    @Test func composeReplacesTheSelectionWithoutContextWhenAsked() async throws {
        let harness = Harness()
        harness.type("Intro: TODO. The end.", selection: NSRange(location: 7, length: 5))
        harness.model.startCompose()
        harness.model.setComposeUsesText(false)
        harness.model.compose("an intro")
        try await waitUntil { harness.model.compose?.result == .ready("<an intro>") }
        #expect(harness.composer.calls.first?.context == nil)
        #expect(harness.surface.decorations.last?.rewriteTarget == NSRange(location: 7, length: 5))

        harness.model.insertComposed()
        #expect(harness.surface.text == "Intro: <an intro> The end.")
    }

    @Test func composeIsNotInsertedWhenTheSelectionChanged() async throws {
        let harness = Harness()
        harness.type("Keep THIS here.", selection: NSRange(location: 5, length: 4))
        harness.model.startCompose()
        harness.model.compose("x")
        try await waitUntil { harness.model.compose?.result == .ready("<x>") }
        harness.type("Keep that here.")
        harness.model.insertComposed()
        #expect(harness.surface.text == "Keep that here.")
        guard case .failed? = harness.model.compose?.result else {
            Issue.record("expected a failure message")
            return
        }
    }

    @Test func composeAndRewriteReplaceEachOther() {
        let harness = Harness()
        harness.type("Some text here.")
        harness.model.sidebarTab = .insights
        harness.model.startCompose()
        #expect(harness.model.sidebarTab == .suggestions, "the card is on the Suggestions tab")
        harness.model.startRewrite(.formal)
        #expect(harness.model.compose == nil && harness.model.rewrite != nil)
        harness.model.startCompose()
        #expect(harness.model.rewrite == nil && harness.model.compose != nil)
    }
}

extension EditorModelTests {
    @Test func plagiarismMatchesAreHighlightedOnlyInTheirTab() async throws {
        let harness = Harness()
        let text = "We hold these truths to be self-evident, that all men are created equal. Mine."
        harness.type(text)
        harness.model.sidebarTab = .plagiarism
        harness.model.checkPlagiarism()
        try await waitUntil { harness.surface.decorations.last?.plagiarism.isEmpty == false }

        let passage = NSRange(location: 0, length: 72)
        #expect(harness.surface.decorations.last?.plagiarism == [passage])
        let source = try #require(harness.plagiarism.lastReport?.sources.first)
        harness.model.revealPlagiarism(source)
        #expect(harness.surface.revealed.last == passage)
        #expect(harness.surface.decorations.last?.selectedPlagiarism == [passage])

        harness.model.sidebarTab = .suggestions
        #expect(harness.surface.decorations.last?.plagiarism.isEmpty == true)
        harness.model.openPlagiarismSettings()
        #expect(harness.openedPlagiarismSettings == 1)
    }

    @Test func editingInsideAMatchDropsItsHighlight() async throws {
        let harness = Harness()
        let text = "Intro. We hold these truths to be self-evident, that all men are created equal."
        harness.type(text)
        harness.model.sidebarTab = .plagiarism
        harness.model.checkPlagiarism()
        try await waitUntil { harness.model.plagiarism.matches.count == 1 }

        harness.type("A longer intro. " + text.dropFirst(7))
        #expect(harness.model.plagiarism.matches == [NSRange(location: 16, length: 72)])
        #expect(harness.model.plagiarism.isStale)
        harness.type("A longer intro. We hold these truths to be obvious, that all men are created equal.")
        #expect(harness.model.plagiarism.matches.isEmpty)
    }
}

private extension ToneState {
    var isReady: Bool {
        if case .ready = self { true } else { false }
    }
}

@MainActor
private final class Harness {
    let checker: FakeChecker
    let rewriter = FakeRewriter()
    let toneDetector = FakeToneDetector()
    let composer = FakeComposer()
    let plagiarism = FakePlagiarismChecker()
    let surface = FakeSurface()
    let model: EditorModel
    private let recorder = Recorder()

    var savedGoals: [WritingGoals] { recorder.savedGoals }
    var dictionary: [String] { recorder.dictionary }
    var openedPlagiarismSettings: Int { recorder.openedPlagiarismSettings }

    init(style: WritingStyle = .neutral, aiStatus: AIStatus = .completed, typingSettle: Duration = .zero, aiEnabled: Bool = true) {
        checker = FakeChecker(aiStatus: aiStatus)
        var settings = AppSettings()
        settings.editorGoals = WritingGoals(style: style)
        settings.aiEnabled = aiEnabled
        let recorder = recorder
        let services = EditorServices(
            checker: checker,
            rewriter: rewriter,
            toneDetector: toneDetector,
            composer: composer,
            plagiarism: plagiarism,
            settings: { settings },
            saveGoals: { recorder.savedGoals.append($0) },
            addToDictionary: { recorder.dictionary.append($0) },
            openSettings: {},
            openPlagiarismSettings: { recorder.openedPlagiarismSettings += 1 }
        )
        model = EditorModel(services: services, checkDebounce: .zero, typingSettle: typingSettle, toneDebounce: .zero)
        surface.model = model
        model.surface = surface
    }

    func type(_ text: String, caret: Int? = nil, selection: NSRange? = nil) {
        surface.text = text
        let range = selection ?? NSRange(location: caret ?? (text as NSString).length, length: 0)
        surface.selection = range
        model.textDidChange(text, selection: range)
    }
}

private final class Recorder {
    var savedGoals: [WritingGoals] = []
    var dictionary: [String] = []
    var openedPlagiarismSettings = 0
}

@MainActor
private final class FakeSurface: EditorTextSurface {
    weak var model: EditorModel?
    var text = ""
    var selection = NSRange(location: 0, length: 0)
    var decorations: [EditorDecorations] = []
    var revealed: [NSRange] = []

    func replaceText(in range: NSRange, with replacement: String) -> Bool {
        let ns = text as NSString
        guard NSMaxRange(range) <= ns.length else { return false }
        text = ns.replacingCharacters(in: range, with: replacement)
        model?.textDidChange(text, selection: selection)
        return true
    }

    func reveal(_ range: NSRange) {
        revealed.append(range)
    }

    func decorate(_ decorations: EditorDecorations) {
        self.decorations.append(decorations)
    }
}

private final class FakeChecker: GrammarChecking, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: (requests: [CheckRequest](), learned: [String]()))
    private let aiStatus: AIStatus

    init(aiStatus: AIStatus) {
        self.aiStatus = aiStatus
    }

    var requests: [CheckRequest] { state.withLock { $0.requests } }
    var learned: [String] { state.withLock { $0.learned } }

    func check(_ request: CheckRequest) -> AsyncStream<CheckResult> {
        state.withLock { $0.requests.append(request) }
        let ns = request.text as NSString
        var issues: [TextIssue] = []
        let rules: [(String, String, IssueCategory, IssueSource)] = [
            ("has", "have", .grammar, .ai),
            ("teh", "the", .spelling, .local),
            ("very unique", "unique", .style, .ai),
        ]
        for (word, fix, category, source) in rules {
            let range = ns.range(of: word)
            if range.location != NSNotFound {
                issues.append(TextIssue(range: range, originalText: word, replacements: [fix], message: "Fix it.", category: category, source: source))
            }
        }
        issues.sort { $0.range.location < $1.range.location }
        let result = CheckResult(text: request.text, issues: issues, language: "en", aiStatus: aiStatus)
        return AsyncStream { continuation in
            continuation.yield(result)
            continuation.finish()
        }
    }

    func learnWord(_ word: String) {
        state.withLock { $0.learned.append(word) }
    }
}

private final class FakeRewriter: TextRewriting, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [RewriteTone]())

    var tones: [RewriteTone] { state.withLock { $0 } }

    func rewrite(_ text: String, tone: RewriteTone, settings: AppSettings) async throws -> String {
        state.withLock { $0.append(tone) }
        return "[\(tone.rawValue)] \(text)"
    }

    func rewrite(_ text: String, instruction: String, settings: AppSettings) async throws -> String {
        "[\(instruction)] \(text)"
    }

    func validateAPIKey(_ key: String, model: String) async throws {}
}

final class FakeComposer: TextComposing, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [(request: String, context: String?)]())

    var calls: [(request: String, context: String?)] { state.withLock { $0 } }

    func compose(_ request: String, context: String?, settings: AppSettings) async throws -> String {
        state.withLock { $0.append((request, context)) }
        return "<\(request)>"
    }
}

final class FakeToneDetector: ToneDetecting, @unchecked Sendable {
    private let state = OSAllocatedUnfairLock(initialState: [String]())
    let failure = OSAllocatedUnfairLock<RewriteError?>(initialState: nil)

    var texts: [String] { state.withLock { $0 } }

    func detectTone(_ text: String, settings: AppSettings) async throws -> ToneReport {
        state.withLock { $0.append(text) }
        if let failure = failure.withLock({ $0 }) { throw failure }
        let tone: DetectedTone = text.contains("!") ? .enthusiastic : .neutral
        return ToneReport(tones: [ToneScore(tone: tone, intensity: .moderate)], sentiment: .positive, summary: "Fine.")
    }
}

@MainActor
func waitUntil(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while !condition() {
        guard ContinuousClock.now < deadline else {
            Issue.record("Timed out waiting", sourceLocation: sourceLocation)
            return
        }
        try await Task.sleep(for: .milliseconds(5))
    }
}
