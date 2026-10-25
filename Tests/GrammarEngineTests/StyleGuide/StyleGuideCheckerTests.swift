import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct StyleGuideCheckerTests {
    private func fixes(_ text: String, _ rules: [StyleRule]) -> [String] {
        StyleGuideChecker.issues(in: text, rules: rules).map { "\(substring(text, $0.range))→\($0.replacements.first ?? "∅")" }
    }

    @Test func flagsWholeWordsAndKeepsCapitals() {
        let rules = [StyleRule(term: "utilize", replacement: "use")]
        #expect(fixes("Utilize it; we utilize; underutilize stays.", rules) == ["Utilize→Use", "utilize→use"])
        let issue = StyleGuideChecker.issues(in: "utilize", rules: rules).first
        #expect(issue?.source == .styleGuide && issue?.category == .wordChoice)
        #expect(issue?.message == "Your style guide says to write “use”.")
    }

    @Test func capitalisationRulesAreAppliedAsWritten() {
        let rules = [StyleRule(term: "Github", replacement: "GitHub")]
        #expect(fixes("github, Github, GITHUB and GitHub.", rules) == ["github→GitHub", "Github→GitHub", "GITHUB→GitHub"])
    }

    @Test func matchCaseFlagsOnlyThatSpelling() {
        let rules = [StyleRule(term: "US", replacement: "U.S.", matchCase: true)]
        #expect(fixes("The US and us.", rules) == ["US→U.S."])
    }

    @Test func avoidRulesHaveNoReplacementAndUseTheNote() {
        let rules = [StyleRule(term: "basically", note: "Filler: cut it.")]
        let issues = StyleGuideChecker.issues(in: "It basically works.", rules: rules)
        #expect(issues.map(\.replacements) == [[]])
        #expect(issues.first?.message == "Filler: cut it.")
        #expect(StyleGuideChecker.message(for: StyleRule(term: "basically")) == "Your style guide says to avoid “basically”.")
    }

    @Test func phrasesMatchAcrossWhitespaceAndLongerTermsWin() {
        let rules = [StyleRule(term: "e-mail", replacement: "email"), StyleRule(term: "e-mail address", replacement: "address")]
        #expect(fixes("Your e-mail\naddress and e-mail.", rules) == ["e-mail\naddress→address", "e-mail→email"])
    }

    @Test func urlsCodeAndBlankRulesAreIgnored() {
        let rules = [StyleRule(term: "utilize", replacement: "use"), StyleRule(term: "  ")]
        #expect(fixes("See https://example.com/utilize and `utilize`.", rules).isEmpty)
        #expect(fixes("anything", []).isEmpty)
    }

    @Test func styleGuideWinsOverOverlappingAIAndLocalIssues() {
        let rule = issue(4, "Github", .wordChoice, source: .styleGuide, replacements: ["GitHub"])
        let spelling = issue(4, "Github", .spelling, replacements: ["Git hub"])
        let ai = issue(0, "the Github", .grammar, source: .ai, replacements: ["GitHub"])
        let unrelated = issue(20, "teh", .spelling, replacements: ["the"])
        let merged = IssueMerger.merge(local: [spelling, unrelated, rule], ai: [ai], settings: AppSettings())
        #expect(merged == [rule, unrelated])
    }

    @Test func theEngineRunsTheStyleGuide() async {
        let engine = makeEngine()
        let settings = testSettings { $0.aiEnabled = false; $0.styleGuide = [StyleRule(term: "utilize", replacement: "use")] }
        let results = await collect(engine.check(CheckRequest(text: "We utilize it.", bundleID: nil, settings: settings)))
        #expect(results.last?.issues.map(\.originalText) == ["utilize"])
    }
}
