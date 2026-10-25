import Foundation
import GrammarAppUI
import GrammarModels
import Testing
@testable import GrammarReviewApp

@MainActor
@Suite(.timeLimit(.minutes(1))) struct FieldSessionTests {
    @Test func checksTheFieldsTextWithTheAppsGoals() async throws {
        try await withSettings { store in
            store.setGoals(WritingGoals(style: .formal), forApp: "com.apple.TextEdit")
            let h = SessionHarness("I has teh cat.", settings: store, respond: answering([issue(2, "has", .grammar, source: .ai), issue(6, "teh")]))
            #expect(h.session.text == "I has teh cat.")
            #expect(h.session.status == .checking)
            try await h.check()

            let request = try #require(h.engine.requests.first)
            #expect(request.text == "I has teh cat.")
            #expect(request.bundleID == "com.apple.TextEdit")
            #expect(request.goals == WritingGoals(style: .formal))
            #expect(request.settings == store.settings)
            #expect(h.session.issues.map(\.originalText) == ["has", "teh"])
            #expect(h.session.status == .done)
        }
    }

    @Test(arguments: [
        (AIStatus.pending, CheckStatus.checking),
        (.completed, .done),
        (.disabled, .done),
        (.missingAPIKey, .aiUnavailable("Add an Anthropic API key in Settings to get grammar and style suggestions.")),
        (.textTooLong, .aiUnavailable("This text is too long for AI checks; showing spelling only.")),
        (.failed("You're offline"), .aiUnavailable("You're offline")),
    ])
    func theAIStatusBecomesTheBadgesStatus(aiStatus: AIStatus, expected: CheckStatus) async throws {
        try await withSettings { store in
            let h = SessionHarness("Some text.", settings: store, respond: answering([], aiStatus))
            try await h.check()
            #expect(h.session.status == expected)
        }
    }

    @Test func aNewerCheckReplacesOneStillWaiting() async throws {
        try await withSettings { store in
            let h = SessionHarness("First.", settings: store, respond: answering([]))
            h.session.scheduleCheck(after: .seconds(30))
            h.field.text = "First, edited."
            #expect(h.session.refreshText())
            try await h.check()
            #expect(h.engine.requests.map(\.text) == ["First, edited."])
        }
    }

    @Test func endingTheSessionStopsItsChecks() async throws {
        try await withSettings { store in
            let h = SessionHarness("Some text.", settings: store)
            try await h.startCheck()
            h.session.end()
            h.engine.send(result("Some text.", [issue(0, "Some")]))

            h.session.scheduleCheck(after: .milliseconds(10))
            h.session.end()
            try await Task.sleep(for: .milliseconds(60))
            #expect(h.results == 0, "the running check's result is dropped")
            #expect(h.engine.requests.count == 1, "the waiting check never starts")
            #expect(h.session.issues.isEmpty)
        }
    }

    @Test func aResultForOlderTextIsMovedOntoWhatTheFieldSaysNow() async throws {
        try await withSettings { store in
            let h = SessionHarness("teh cat", settings: store)
            #expect(!h.session.refreshText(), "nothing changed")
            h.field.text = nil
            #expect(!h.session.refreshText(), "an unreadable field keeps the last text")

            try await h.startCheck()
            h.field.text = "So teh cat"
            #expect(h.session.refreshText())
            #expect(h.session.text == "So teh cat")
            try await h.send(result("teh cat", [issue(0, "teh")]))
            #expect(h.session.issues.map(\.range.location) == [3])
        }
    }

    @Test func aiSuggestionsStayUntilTheNextAIAnswer() async throws {
        try await withSettings { store in
            let text = "I has teh cat."
            let h = SessionHarness(text, settings: store)
            try await h.startCheck()
            try await h.send(result(text, [issue(2, "has", .grammar, source: .ai), issue(6, "teh cat", .grammar, source: .ai)]))

            try await h.startCheck()
            try await h.send(result(text, [issue(6, "teh")], .pending))
            #expect(h.session.issues.map(\.originalText) == ["has", "teh"], "AI suggestions that don't overlap the new spelling stay")
            #expect(h.session.status == .checking)

            try await h.send(result(text, [issue(6, "teh")]))
            #expect(h.session.issues.map(\.originalText) == ["teh"])
            #expect(h.session.status == .done)
        }
    }

    @Test func ignoredSuggestionsStayHiddenUntilRestored() async throws {
        try await withSettings { store in
            let issues = [issue(0, "teh"), issue(4, "has", .grammar, source: .ai), issue(8, "teh")]
            let h = SessionHarness("teh has teh", settings: store, respond: answering(issues))
            try await h.check()
            h.session.ignore(h.session.issues[0])
            #expect(h.session.issues.map(\.originalText) == ["has"])
            #expect(h.session.ignoredIssues.map(\.originalText) == ["teh"])

            try await h.check()
            #expect(h.session.issues.map(\.originalText) == ["has"])

            h.session.restore(h.session.ignoredIssues[0])
            #expect(h.session.issues.map(\.range.location) == [0, 4, 8])
            #expect(h.session.ignoredIssues.isEmpty)
        }
    }

    @Test func aFixIsTypedIntoTheFieldAndTheOtherSuggestionsMove() async throws {
        try await withSettings { store in
            let issues = [issue(2, "has", .grammar, source: .ai, replacements: ["have"]), issue(6, "teh", replacements: ["the"])]
            let h = SessionHarness("I has teh cat.", settings: store, respond: answering(issues))
            try await h.check()
            #expect(h.session.applyFix("have", to: h.session.issues[0].id))
            #expect(h.field.text == "I have teh cat.")
            #expect(h.field.replacements == ["2+3→have"])
            #expect(h.session.text == "I have teh cat.")
            #expect(h.session.issues.map(\.originalText) == ["teh"])
            #expect(h.session.issues.map(\.range.location) == [7])
        }
    }

    @Test func aFixFollowsTextTypedSinceTheCheck() async throws {
        try await withSettings { store in
            let h = SessionHarness("I has teh cat.", settings: store, respond: answering([issue(6, "teh", replacements: ["the"])]))
            try await h.check()
            h.field.text = "Well, I has teh cat."
            #expect(h.session.applyFix("the", to: h.session.issues[0].id))
            #expect(h.field.replacements == ["12+3→the"])
            #expect(h.field.text == "Well, I has the cat.")
        }
    }

    @Test func aFixThatNoLongerFitsOrIsRefusedIsSkipped() async throws {
        try await withSettings { store in
            let issues = [issue(2, "has", .grammar, source: .ai, replacements: ["have"]), issue(6, "teh", replacements: ["the"])]
            let h = SessionHarness("I has teh cat.", settings: store, respond: answering(issues))
            try await h.check()
            let teh = h.session.issues[1]
            h.field.text = "I has tea cat."
            #expect(!h.session.applyFix("the", to: teh.id), "the misspelling was retyped")
            #expect(h.field.text == "I has tea cat.")

            h.field.acceptsReplacements = false
            let has = try #require(h.session.issues.first)
            #expect(!h.session.applyFix("have", to: has.id))
            #expect(h.session.issues.map(\.id) == [has.id], "a fix the app refused stays listed")
            #expect(h.field.replacements.isEmpty)
        }
    }

    @Test func fixAllWorksFromTheEndOfTheText() async throws {
        try await withSettings { store in
            let issues = [
                issue(0, "teh", replacements: ["the"]),
                issue(4, "has", .grammar, source: .ai, replacements: ["have"]),
                issue(12, "very unique", .style, source: .ai, replacements: ["unique"]),
                issue(25, "wrod", replacements: []),
            ]
            let h = SessionHarness("teh has it, very unique, wrod", settings: store, respond: answering(issues))
            try await h.check()
            let fixes = h.session.correctnessFixes
            #expect(fixes.map(\.originalText) == ["has", "teh"], "correctness fixes with a replacement, last first")

            for fix in fixes {
                #expect(h.session.applyFix(fix.replacements[0], to: fix.id))
            }
            #expect(h.field.text == "the have it, very unique, wrod")
            #expect(h.session.issues.map(\.originalText) == ["very unique", "wrod"])
        }
    }

    @Test func learningAWordDropsEverySpellingOfItShownOrIgnored() async throws {
        try await withSettings { store in
            let issues = [issue(0, "Teh"), issue(4, "teh"), issue(8, "has", .grammar, source: .ai), issue(12, "teh")]
            let h = SessionHarness("Teh teh has teh", settings: store, respond: answering(issues))
            try await h.check()
            h.session.ignore(h.session.issues[1])
            #expect(h.session.issues.map(\.originalText) == ["Teh", "has"])

            h.session.removeSpelling(of: "TEH")
            #expect(h.session.issues.map(\.originalText) == ["has"])
            #expect(h.session.ignoredIssues.isEmpty)
        }
    }
}
