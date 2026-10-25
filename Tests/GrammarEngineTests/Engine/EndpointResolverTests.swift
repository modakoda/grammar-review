import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct EndpointResolverTests {
    @Test func aCloudServiceGetsItsTrimmedKeyAndTheChosenModel() async {
        let resolver = EndpointResolver(apiKeys: { provider in provider == .cloud("openai") ? "  sk-proj-test \n" : nil })
        var settings = testSettings { $0.aiProvider = .cloud("openai") }
        settings.cloudModels["openai"] = "gpt-6.1-sol"
        #expect(await resolver.resolve(settings) == .success(.cloud(service: .openAI, model: "gpt-6.1-sol", apiKey: "sk-proj-test")))
    }

    @Test func aServiceThatIsNoLongerOfferedAsksForAnother() async {
        let resolver = EndpointResolver(apiKeys: { _ in "sk-test" })
        let settings = testSettings { $0.aiProvider = .cloud("retired") }
        #expect(await resolver.resolve(settings) == .failure(.notConfigured("Choose an AI service in Settings → AI")))
        await #expect(throws: RewriteError.failed("Choose an AI service in Settings → AI")) {
            try await resolver.require(settings)
        }
    }

    @Test func aiErrorsBecomeRewriteErrorsWordedForTheEndpoint() {
        let claude = AIEndpoint.claude(model: "claude-haiku-5-5", apiKey: "sk-ant")
        let openAI = AIEndpoint.cloud(service: .openAI, model: "gpt-6-luna", apiKey: "sk-proj")
        let local = AIEndpoint.local(baseURL: URL(string: "http://localhost:1234/v1")!, model: "qwen3-30b-a3b")
        #expect(AIError.cancelled.rewriteError(for: openAI) is CancellationError)
        #expect(AIError.invalidAPIKey.rewriteError(for: claude) as? RewriteError == .invalidAPIKey)
        #expect(AIError.invalidAPIKey.rewriteError(for: openAI) as? RewriteError == .failed("Invalid OpenAI API key"),
                "RewriteError.invalidAPIKey is worded for an Anthropic key")
        #expect(AIError.busy.rewriteError(for: local) as? RewriteError == .failed("The local server is busy — try again shortly"))
    }
}
