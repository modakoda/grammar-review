import GrammarModels
import Testing
@testable import GrammarOverlay

@Suite struct BadgeAppearanceTests {
    @Test func doneWithoutIssuesIsAGreenCheckmark() {
        let badge = BadgeAppearance(issues: [], status: .done)
        #expect(badge.glyph == .checkmark)
        #expect(badge.tint == .success)
        #expect(!badge.showsActivityRing)
    }

    @Test func checkingWithoutIssuesIsASpinner() {
        let badge = BadgeAppearance(issues: [], status: .checking)
        #expect(badge.glyph == .spinner)
        #expect(badge.tint == .neutral)
        #expect(!badge.showsActivityRing)
    }

    @Test func aiUnavailableWithoutIssuesIsAnOrangeWarningWithTheMessage() {
        let badge = BadgeAppearance(issues: [], status: .aiUnavailable("Add an API key in Settings"))
        #expect(badge.glyph == .warning)
        #expect(badge.tint == .warning)
        #expect(badge.tooltip == "Add an API key in Settings")
    }

    @Test func countIsColouredByTheMostSevereIssue() {
        let badge = BadgeAppearance(issues: [makeIssue(.style), makeIssue(.clarity)], status: .done)
        #expect(badge.glyph == .count("2"))
        #expect(badge.tint == .severity(.clarity))
        #expect(!badge.showsActivityRing)
        #expect(!badge.showsWarningDot)
        #expect(badge.tooltip == "2 suggestions")

        let withSpelling = BadgeAppearance(issues: [makeIssue(.style), makeIssue(.spelling)], status: .done)
        #expect(withSpelling.tint == .severity(.correctness))
    }

    @Test func checkingWithIssuesShowsTheCountAndAnActivityRing() {
        let badge = BadgeAppearance(issues: [makeIssue(.grammar)], status: .checking)
        #expect(badge.glyph == .count("1"))
        #expect(badge.tint == .severity(.correctness))
        #expect(badge.showsActivityRing)
    }

    @Test func aiUnavailableWithIssuesKeepsTheCountAndAddsAWarningDot() {
        let badge = BadgeAppearance(issues: [makeIssue(.spelling)], status: .aiUnavailable("You're offline"))
        #expect(badge.glyph == .count("1"))
        #expect(badge.showsWarningDot)
        #expect(badge.tooltip.contains("You're offline"))
    }

    @Test func largeCountsAreCapped() {
        let issues = (0..<150).map { _ in makeIssue() }
        #expect(BadgeAppearance(issues: issues, status: .done).glyph == .count("99+"))
    }
}
