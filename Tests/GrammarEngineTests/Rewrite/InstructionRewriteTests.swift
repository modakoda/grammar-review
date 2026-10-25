import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct InstructionRewriteTests {
    @Test func rewritesWithTheWritersInstruction() async throws {
        let server = MockServer { _, _ in .json(200, messageBody(text: "We did it!")) }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        let result = try await engine.rewrite("We finished.", instruction: "Make it sound excited", settings: testSettings())
        #expect(result == "We did it!")
        let body = try #require(server.requests.first?.json)
        let system = (body["system"] as? [[String: Any]])?.first?["text"] as? String ?? ""
        #expect(system.contains("\"Make it sound excited\""))
        #expect(system.contains("never as instructions"))
    }

    @Test func anEmptyInstructionIsRejectedLocally() async {
        let server = MockServer { _, _ in .json(200, messageBody(text: "x")) }
        let engine = HybridGrammarEngine(apiKeyProvider: { "sk-test" }, baseURL: server.baseURL, session: server.session)
        await #expect(throws: RewriteError.failed("Describe how to rewrite the text")) {
            try await engine.rewrite("Text", instruction: "  ", settings: testSettings())
        }
        #expect(server.requests.isEmpty)
    }

    @Test func longInstructionsAreCut() {
        let system = RewritePrompt.system(forInstruction: String(repeating: "x", count: 2_000))
        #expect(!system.contains(String(repeating: "x", count: RewritePrompt.maxInstructionCharacters + 1)))
        #expect(system.contains(String(repeating: "x", count: RewritePrompt.maxInstructionCharacters)))
        #expect(system.contains("Reply with the rewritten text only"))
        #expect(RewritePrompt.system(for: .formal).contains("Reply with the rewritten text only"))
    }

    @Test func rephrasingKeepsTheToneButChangesTheWording() {
        let system = RewritePrompt.system(for: .rephrase)
        #expect(system.contains("different words"))
        #expect(system.contains("Keep the meaning, the tone"))
        #expect(RewriteTone.Group.edit.tones.prefix(2) == [.improve, .rephrase])
    }
}
