import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct ConsistencyCheckerTests {
    private func fixes(_ text: String, language: String? = "en") -> [String] {
        ConsistencyChecker.issues(in: text, language: language).map { issue in
            "\(substring(text, issue.range))→\(issue.replacements.first ?? "")"
        }
    }

    @Test func hyphenatedVariantsFollowTheMajority() {
        #expect(fixes("Send an email. I read every email. Reply by e-mail.") == ["e-mail→email"])
        #expect(fixes("We co-operate. They co-operate. Teams cooperate.") == ["cooperate→co-operate"])
        let issue = ConsistencyChecker.issues(in: "email, email, E-mail", language: "en").first
        #expect(issue?.replacements == ["Email"], "keeps the capital")
        #expect(issue?.category == .wordChoice && issue?.source == .local)
    }

    @Test func aTieOrASingleFormIsNotFlagged() {
        #expect(fixes("An email and an e-mail.").isEmpty)
        #expect(fixes("A well-known, well-known fact.").isEmpty)
        #expect(fixes("").isEmpty)
    }

    @Test func britishAndAmericanSpellingFollowTheMajority() {
        #expect(fixes("The colour and the flavour of the color.") == ["color→colour"])
        #expect(fixes("We organized it, realized it and then Organised it.") == ["Organised→Organized"])
        #expect(fixes("Travelled far; traveled more; traveled home.") == ["Travelled→Traveled"])
    }

    @Test func aBritishAmericanTieFollowsTheUsersVariant() {
        let text = "The colour of the center."
        #expect(fixes(text, language: "en-GB") == ["center→centre"])
        #expect(fixes(text, language: "en_US") == ["colour→color"])
        #expect(fixes(text, language: "en").isEmpty)
    }

    @Test func spellingVariantsAreOnlyCheckedInEnglish() {
        #expect(fixes("colour colour color", language: "fr").isEmpty)
        #expect(fixes("colour colour color", language: nil) == ["color→colour"], "undetermined language may be English")
    }

    @Test func mixedQuotationMarksFollowTheMajority() {
        let text = "He said “yes” and “no”, then \"maybe\"."
        #expect(fixes(text) == ["\"→\u{201C}", "\"→\u{201D}"])
        #expect(fixes("\"a\" \"b\" “c”") == ["“→\"", "”→\""])
    }

    @Test func mixedApostrophesFollowTheMajority() {
        #expect(fixes("I don’t know, it’s fine, isn't it?") == ["'→’"])
        #expect(fixes("don’t say 'no'").isEmpty)
    }

    @Test func urlsAndCodeAreIgnored() {
        #expect(fixes("email email see https://example.com/e-mail and `e-mail`").isEmpty)
    }

    @Test func helpers() {
        #expect(ConsistencyChecker.strictMajority(["a", "b", "a"]) == "a")
        #expect(ConsistencyChecker.strictMajority(["a", "b"]) == nil)
        #expect(ConsistencyChecker.strictMajority(["a"]) == nil)
        #expect(ConsistencyChecker.matchingCase(of: "COLOUR", "color") == "COLOR")
        #expect(ConsistencyChecker.matchingCase(of: "Colour", "color") == "Color")
        #expect(ConsistencyChecker.matchingCase(of: "colour", "color") == "color")
        #expect(SpellingVariantConsistency.britishToAmerican["colours"] == "colors")
        #expect(SpellingVariantConsistency.britishToAmerican["organisation"] == "organization")
        #expect(SpellingVariantConsistency.americanToBritish["modeling"] == "modelling")
    }

    @Test func aiIssuesWinOverOverlappingConsistencyIssues() {
        let consistency = issue(4, "e-mail", .wordChoice, replacements: ["email"])
        let ai = issue(0, "the e-mail", .grammar, source: .ai, replacements: ["an email"])
        let merged = IssueMerger.merge(local: [consistency], ai: [ai], settings: AppSettings())
        #expect(merged == [ai])
    }
}
