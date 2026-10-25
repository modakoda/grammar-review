import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct RewritePromptTests {
    @Test func cleanStripsWrappersButKeepsSelectionWhitespace() {
        #expect(RewritePrompt.clean("\"Hello there.\"", original: "hello there ") == "Hello there. ")
        #expect(RewritePrompt.clean("```\nHello.\n```", original: "  hi") == "  Hello.")
        #expect(RewritePrompt.clean("<text>\nHello.\n</text>", original: "hi") == "Hello.")
        #expect(RewritePrompt.clean("“Quoted”", original: "“quoted”") == "“Quoted”")
        #expect(RewritePrompt.clean("  Plain.\n", original: "plain") == "Plain.")
    }

    @Test func toneInstructionsDiffer() {
        let prompts = Set(RewriteTone.allCases.map(RewritePrompt.system(for:)))
        #expect(prompts.count == RewriteTone.allCases.count)
        for tone in RewriteTone.allCases {
            #expect(RewritePrompt.system(for: tone).contains("Never translate"))
            #expect(RewritePrompt.system(for: tone).contains("Never add facts"))
        }
    }

    @Test func toneGroupsListEveryToneOnceInOrder() {
        #expect(RewriteTone.Group.allCases.flatMap(\.tones) == RewriteTone.allCases)
        #expect(RewriteTone.Group.edit.tones.first == .improve, "the default tone comes first")
        #expect(RewriteTone.Group.tone.tones.starts(with: [.professional, .formal, .informal]))
        #expect(Set(RewriteTone.allCases.map(\.displayName)).count == RewriteTone.allCases.count)
    }

    @Test func maxTokensScalesWithInput() {
        #expect(RewritePrompt.maxTokens(for: "short") < RewritePrompt.maxTokens(for: String(repeating: "word ", count: 1000)))
        #expect(RewritePrompt.maxTokens(for: String(repeating: "x", count: 100_000)) == 16_000)
    }
}
