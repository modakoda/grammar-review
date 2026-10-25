import GrammarModels
import Testing
@testable import GrammarOverlay

@Suite struct IssueSummaryTests {
    @Test func fixAllCountsCorrectnessIssuesWithAReplacement() {
        let issues = [
            makeIssue(.spelling, replacements: ["the"]),
            makeIssue(.grammar, replacements: ["is", "was"]),
            makeIssue(.punctuation, replacements: [","]),
            makeIssue(.spelling, replacements: []),
            makeIssue(.clarity, replacements: ["clearer"]),
            makeIssue(.wordChoice, replacements: ["better"]),
            makeIssue(.style, replacements: ["nicer"]),
        ]
        #expect(IssueSummary.fixAllCount(issues) == 3)
        #expect(IssueSummary.fixAllCount([]) == 0)
    }

    @Test func fixAllCountsDeletionsToo() {
        #expect(IssueSummary.fixAllCount([makeIssue(.grammar, original: "the the", replacements: ["the"]),
                                          makeIssue(.punctuation, original: ",", replacements: [""])]) == 2)
    }

    @Test func mostSevereFollowsCorrectnessClarityStyle() {
        #expect(IssueSummary.mostSevere([]) == nil)
        #expect(IssueSummary.mostSevere([makeIssue(.style)]) == .style)
        #expect(IssueSummary.mostSevere([makeIssue(.style), makeIssue(.wordChoice)]) == .clarity)
        #expect(IssueSummary.mostSevere([makeIssue(.style), makeIssue(.clarity), makeIssue(.punctuation)]) == .correctness)
    }

    @Test func labels() {
        #expect(IssueSummary.countLabel(7) == "7")
        #expect(IssueSummary.countLabel(99) == "99")
        #expect(IssueSummary.countLabel(100) == "99+")
        #expect(IssueSummary.title(forCount: 0) == "No suggestions")
        #expect(IssueSummary.title(forCount: 1) == "1 suggestion")
        #expect(IssueSummary.title(forCount: 4) == "4 suggestions")
        #expect(IssueSummary.disableTitle(appName: "Notes") == "Disable in Notes")
        #expect(IssueSummary.disableTitle(appName: nil) == "Disable in this app")
        #expect(IssueSummary.disableTitle(appName: "  ") == "Disable in this app")
    }

    @Test func toneDescriptionListsTonesWithEmoji() {
        let report = ToneReport(
            tones: [ToneScore(tone: .confident, intensity: .strong), ToneScore(tone: .friendly, intensity: .slight)],
            sentiment: .positive,
            summary: ""
        )
        #expect(IssueSummary.toneDescription(report) == "😎 Confident · 🤗 Friendly")
        #expect(IssueSummary.toneDescription(ToneReport(tones: [], sentiment: .neutral, summary: "")).isEmpty)
    }

    @Test func whitespaceOnlyTextIsMadeVisible() {
        #expect(IssueSummary.visibleText("word") == "word")
        #expect(IssueSummary.visibleText("") == "")
        #expect(IssueSummary.visibleText(" ") == "␣")
        #expect(IssueSummary.visibleText("  ") == "␣␣")
        #expect(IssueSummary.visibleText("\n") == "↵")
        #expect(IssueSummary.visibleText("a b") == "a b")
    }
}
