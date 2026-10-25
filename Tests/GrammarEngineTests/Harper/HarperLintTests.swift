import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct HarperLintTests {
    static let uri = "untitled:grammar-review-1"

    private func range(_ line: Int, _ start: Int, _ end: Int) -> LSPRange {
        LSPRange(start: LSPPosition(line: line, character: start), end: LSPPosition(line: line, character: end))
    }

    private func fix(_ title: String, _ range: LSPRange, _ newText: String) -> LSPCodeAction {
        LSPCodeAction(title: title, edits: [Self.uri: [LSPTextEdit(range: range, newText: newText)]])
    }

    private func ignore(_ kind: String, _ message: String) -> LSPCodeAction {
        LSPCodeAction(title: "Ignore Harper error.", lintKind: kind, lintMessage: message)
    }

    // Recorded from harper-ls 2.13.0.
    static let codeActions = #"""
    {"jsonrpc":"2.0","id":2,"result":[
      {"command":{"arguments":["{}"],"command":"HarperRecordLint","title":"Record lint statistic"},
       "edit":{"changes":{"untitled:grammar-review-1":[{"newText":"a","range":{"end":{"character":10,"line":0},"start":{"character":8,"line":0}}}]}},
       "kind":"quickfix","title":"Replace with: “a”"},
      {"arguments":["untitled:grammar-review-1",{"lint_kind":"Miscellaneous","message":"Incorrect indefinite article.","priority":31,
        "span":{"end":10,"start":8},"suggestions":[{"ReplaceWith":["a"]}]}],
       "command":"HarperIgnoreLint","title":"Ignore Harper error."}
    ]}
    """#

    @Test func decodesHarpersCodeActions() throws {
        let actions = try #require(try JSONDecoder().decode(LSPResponse<[LSPCodeAction]>.self, from: Data(Self.codeActions.utf8)).result)
        #expect(actions.count == 2)
        #expect(actions[0].edits[Self.uri] == [LSPTextEdit(range: range(0, 8, 10), newText: "a")])
        #expect(actions[0].lintKind == nil && !actions[0].isIgnoreCommand)
        #expect(actions[1].lintKind == "Miscellaneous")
        #expect(actions[1].lintMessage == "Incorrect indefinite article.")
        #expect(actions[1].edits.isEmpty)
    }

    @Test func decodesDiagnosticsWithStringOrNumberCodes() throws {
        let json = #"""
        {"jsonrpc":"2.0","method":"textDocument/publishDiagnostics","params":{"uri":"untitled:x","diagnostics":[
          {"code":"AnA","message":"Incorrect indefinite article.","range":{"start":{"line":0,"character":8},"end":{"line":0,"character":10}},"severity":4,"source":"Harper"},
          {"code":7,"message":"Seven.","range":{"start":{"line":1,"character":0},"end":{"line":1,"character":1}}}
        ]}}
        """#
        let published = try JSONDecoder().decode(LSPNotification<LSPPublishDiagnostics>.self, from: Data(json.utf8)).params
        #expect(published.uri == "untitled:x")
        #expect(published.diagnostics.map(\.code) == ["AnA", "7"])
        #expect(published.diagnostics[0].range == range(0, 8, 10))
    }

    @Test func aLintTakesItsRangeKindAndFixesFromTheActions() {
        let text = "This is an test."
        let diagnostic = LSPDiagnostic(range: range(0, 8, 10), message: "Incorrect indefinite article.", code: "AnA")
        let actions = [fix("Replace with: “a”", range(0, 8, 10), "a"), ignore("Miscellaneous", diagnostic.message)]
        let lint = HarperLint(diagnostic: diagnostic, actions: actions, uri: Self.uri, lines: LSPLineIndex(text), text: text as NSString)
        #expect(lint == HarperLint(range: NSRange(location: 8, length: 2), rule: "AnA", kind: "Miscellaneous",
                                   message: "Incorrect indefinite article.", replacements: ["a"]))
    }

    @Test func editsBeyondTheDiagnosticWidenTheLint() {
        let text = "Its fine."
        let diagnostic = LSPDiagnostic(range: range(0, 0, 3), message: "Use it's.", code: nil)
        let actions = [
            fix("Insert", range(0, 2, 2), "'"),
            LSPCodeAction(title: "Two edits", edits: [Self.uri: [
                LSPTextEdit(range: range(0, 0, 3), newText: "It is"),
                LSPTextEdit(range: range(0, 3, 4), newText: " really "),
            ]]),
        ]
        let lint = HarperLint(diagnostic: diagnostic, actions: actions, uri: Self.uri, lines: LSPLineIndex(text), text: text as NSString)
        #expect(lint?.range == NSRange(location: 0, length: 4))
        #expect(lint?.replacements == ["It's ", "It is really "])
    }

    @Test func overlappingLintsKeepTheirOwnFixes() {
        let text = "the the cat"
        let repeated = LSPDiagnostic(range: range(0, 0, 7), message: "Did you mean to repeat this word?", code: "RepeatedWords")
        let capital = LSPDiagnostic(range: range(0, 0, 3), message: "Capitalize the first word.", code: "SentenceCapitalization")
        let actions = [
            fix("Replace with: “the”", range(0, 0, 7), "the"), ignore("Repetition", repeated.message),
            fix("Replace with: “The”", range(0, 0, 3), "The"), ignore("Capitalization", capital.message),
        ]
        let lines = LSPLineIndex(text)
        let first = HarperLint(diagnostic: repeated, actions: actions, uri: Self.uri, lines: lines, text: text as NSString)
        let second = HarperLint(diagnostic: capital, actions: actions, uri: Self.uri, lines: lines, text: text as NSString)
        #expect(first?.replacements == ["the"] && first?.kind == "Repetition")
        #expect(second?.replacements == ["The"] && second?.kind == "Capitalization")
    }

    @Test func editsForOtherDocumentsAndRangesOutsideTheTextAreIgnored() {
        let text = "Short"
        let diagnostic = LSPDiagnostic(range: range(0, 0, 5), message: "m", code: nil)
        let other = LSPCodeAction(title: "Elsewhere", edits: ["untitled:other": [LSPTextEdit(range: range(0, 0, 5), newText: "x")]])
        let lint = HarperLint(diagnostic: diagnostic, actions: [other], uri: Self.uri, lines: LSPLineIndex(text), text: text as NSString)
        #expect(lint?.replacements.isEmpty == true)
        #expect(HarperLint(diagnostic: LSPDiagnostic(range: range(3, 0, 1), message: "m", code: nil), actions: [],
                           uri: Self.uri, lines: LSPLineIndex(text), text: text as NSString) == nil)
    }

    @Test func theDialectFollowsTheLanguageThenTheUsersEnglish() {
        #expect(HarperDialect(language: "en-GB", preferredLanguages: ["en-US"]) == .british)
        #expect(HarperDialect(language: "en", preferredLanguages: ["lt-LT", "en-AU"]) == .australian)
        #expect(HarperDialect(language: "en_CA", preferredLanguages: []) == .canadian)
        #expect(HarperDialect(language: "en-IN", preferredLanguages: []) == .indian)
        #expect(HarperDialect(language: "en-US", preferredLanguages: ["en-GB"]) == .american)
        #expect(HarperDialect(language: "en", preferredLanguages: ["en-LT"]) == .british)
        #expect(HarperDialect(language: "en", preferredLanguages: ["lt-LT"]) == .american)
        #expect(HarperDialect(language: nil, preferredLanguages: []) == .american)
    }

    @Test func theConfigurationTurnsOffSpellingAndLongSentences() {
        let settings = HarperConfiguration(dialect: .british).settings.serialized
        #expect(settings.hasPrefix(#"{"harper-ls":{"dialect":"British""#))
        #expect(settings.contains(#""linters":{"SpellCheck":false,"LongSentences":false}"#))
    }
}
