import Foundation
import Testing
@testable import GrammarAccessibility

@Suite("Replacement planning and verification")
struct ReplacementPlanTests {
    @Test func expectedTextReplacesTheRange() throws {
        let plan = try #require(ReplacementPlan(text: "I has a cat.", range: NSRange(location: 2, length: 3), replacement: "have"))
        #expect(plan.expectedText == "I have a cat.")
        #expect(plan.caretAfter == NSRange(location: 6, length: 0))
    }

    @Test func rangesAreUTF16() throws {
        let text = "Hi 👋 teh cat"
        let range = (text as NSString).range(of: "teh")
        #expect(range.location == 6)
        let plan = try #require(ReplacementPlan(text: text, range: range, replacement: "the 🐈"))
        #expect(plan.expectedText == "Hi 👋 the 🐈 cat")
        #expect(plan.caretAfter == NSRange(location: 6 + 6, length: 0))
    }

    @Test func insertionAndDeletion() throws {
        let insert = try #require(ReplacementPlan(text: "Hello world", range: NSRange(location: 5, length: 0), replacement: ","))
        #expect(insert.expectedText == "Hello, world")
        let delete = try #require(ReplacementPlan(text: "the the cat", range: NSRange(location: 3, length: 4), replacement: ""))
        #expect(delete.expectedText == "the cat")
        #expect(delete.caretAfter == NSRange(location: 3, length: 0))
    }

    @Test func rangeAtTheVeryEndIsValid() throws {
        let plan = try #require(ReplacementPlan(text: "abc", range: NSRange(location: 3, length: 0), replacement: "."))
        #expect(plan.expectedText == "abc.")
    }

    @Test(arguments: [
        NSRange(location: 2, length: 5),
        NSRange(location: 4, length: 0),
        NSRange(location: NSNotFound, length: 0),
        NSRange(location: -1, length: 1),
    ])
    func rangesOutsideTheTextAreRejected(range: NSRange) {
        #expect(ReplacementPlan(text: "abc", range: range, replacement: "x") == nil)
    }

    @Test func rangeSplittingAnEmojiIsRejected() {
        #expect(ReplacementPlan(text: "a👋b", range: NSRange(location: 2, length: 1), replacement: "x") == nil)
        #expect(ReplacementPlan(text: "a👋b", range: NSRange(location: 0, length: 2), replacement: "x") == nil)
        #expect(ReplacementPlan(text: "a👋b", range: NSRange(location: 1, length: 2), replacement: "x") != nil)
    }

    @Test func outcomeClassification() throws {
        let plan = try #require(ReplacementPlan(text: "I has a cat.", range: NSRange(location: 2, length: 3), replacement: "have"))
        #expect(plan.outcome(for: "I have a cat.") == .applied)
        #expect(plan.outcome(for: "I has a cat.") == .unchanged)
        #expect(plan.outcome(for: "I havehas a cat.") == .diverged)
        #expect(plan.outcome(for: nil) == .unreadable)
    }

    @Test func verificationToleratesAppNormalization() throws {
        let plan = try #require(ReplacementPlan(text: "a\r\nteh ", range: NSRange(location: 3, length: 3), replacement: "the"))
        #expect(plan.outcome(for: "a\nthe\u{00A0}") == .applied)
        #expect(plan.outcome(for: "a\nteh ") == .unchanged)
    }

    @Test func noOpReplacementIsApplied() throws {
        let plan = try #require(ReplacementPlan(text: "same", range: NSRange(location: 0, length: 4), replacement: "same"))
        #expect(plan.outcome(for: "same") == .applied)
    }
}
