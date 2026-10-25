import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct StyleGuideFileTests {
    static let rules = [
        StyleRule(term: "utilize", replacement: "use", note: "Plain words, please."),
        StyleRule(term: "US", replacement: "U.S.", matchCase: true),
        StyleRule(term: "basically", note: "Cut it, \"really\""),
    ]

    @Test(arguments: StyleGuideFile.Format.allCases)
    func roundTrips(format: StyleGuideFile.Format) throws {
        let decoded = try StyleGuideFile.decode(StyleGuideFile.encode(Self.rules, as: format))
        #expect(decoded.map(\.term) == Self.rules.map(\.term))
        #expect(decoded.map(\.replacement) == Self.rules.map(\.replacement))
        #expect(decoded.map(\.note) == Self.rules.map(\.note))
        #expect(decoded.map(\.matchCase) == Self.rules.map(\.matchCase))
    }

    @Test func readsHandWrittenFiles() throws {
        let csv = "utilize,use\nleverage;;\n\"e-mail, mail\",email,\"Say \"\"email\"\".\",yes\n\n"
        let rules = try StyleGuideFile.decode(Data(csv.utf8))
        #expect(rules.map(\.term) == ["utilize", "leverage;;", "e-mail, mail"])
        #expect(rules[2].note == "Say \"email\".")
        #expect(rules[2].matchCase)

        let semicolons = try StyleGuideFile.decode(Data("term;replacement;note\nutilise;use;UK spelling\n".utf8))
        #expect(semicolons == [StyleRule(id: semicolons[0].id, term: "utilise", replacement: "use", note: "UK spelling")])

        let json = try StyleGuideFile.decode(Data(#"{"rules":[{"term":"Github","replacement":"GitHub"},{"term":""}]}"#.utf8))
        #expect(json.map(\.term) == ["Github"])
    }

    @Test func badFilesAreErrors() {
        #expect(throws: StyleGuideFile.ReadError.unreadable) { try StyleGuideFile.decode(Data("[{\"nope\":1}]".utf8)) }
        #expect(throws: StyleGuideFile.ReadError.noRules) { try StyleGuideFile.decode(Data("term,replacement\n".utf8)) }
        #expect(throws: StyleGuideFile.ReadError.unreadable) { try StyleGuideFile.decode(Data([0xFF, 0xFE, 0xFD])) }
    }

    @Test func mergingReplacesRulesForTheSameTerm() {
        let existing = [StyleRule(term: "utilize", replacement: "use"), StyleRule(term: "leverage", replacement: "use")]
        let merged = StyleGuideFile.merge([StyleRule(term: "Utilize ", replacement: "employ"), StyleRule(term: "synergy")], into: existing)
        #expect(merged.map(\.term) == ["Utilize ", "leverage", "synergy"])
        #expect(merged[0].replacement == "employ")
        #expect(merged[0].id == existing[0].id, "an updated rule keeps its identity")
    }
}
