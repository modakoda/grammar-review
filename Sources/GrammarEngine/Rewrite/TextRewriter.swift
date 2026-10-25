import Foundation
import GrammarModels

struct TextRewriter: Sendable {
    let backends: AIBackends
    let endpoints: EndpointResolver
    let languages: LanguageSource

    func rewrite(_ text: String, tone: RewriteTone, settings: AppSettings) async throws -> String {
        Log.engine.debug("Rewrite (\(tone.rawValue, privacy: .public)) of \(text.utf16.count, privacy: .public) units")
        return try await rewrite(text, system: RewritePrompt.system(for: tone), settings: settings)
    }

    func rewrite(_ text: String, instruction: String, settings: AppSettings) async throws -> String {
        guard !instruction.trimmedWhitespace.isEmpty else { throw RewriteError.failed("Describe how to rewrite the text") }
        Log.engine.debug("Rewrite (custom instruction) of \(text.utf16.count, privacy: .public) units")
        return try await rewrite(text, system: RewritePrompt.system(forInstruction: instruction), settings: settings)
    }

    private func rewrite(_ text: String, system: String, settings: AppSettings) async throws -> String {
        let trimmed = text.trimmedWhitespace
        guard !trimmed.isEmpty else { throw RewriteError.failed("Select some text to rewrite") }
        guard settings.aiEnabled else { throw RewriteError.failed("AI is turned off in Settings") }
        guard text.utf16.count <= RewritePrompt.maxCharacters else { throw RewriteError.textTooLong }
        let endpoint = try await endpoints.require(settings)

        let language = await languages.resolver(for: settings).language(of: trimmed)
        let request = RewritePrompt.request(text: trimmed, system: system, language: language, model: endpoint.model)

        let name = endpoint.provider.assistantName
        switch await backends.send(request, to: endpoint) {
        case .success(let response):
            if response.stopReason == "refusal" { throw RewriteError.failed("\(name) declined to rewrite this text") }
            if response.stopReason == "max_tokens" { throw RewriteError.failed("The rewrite was cut off — try a shorter selection") }
            let cleaned = RewritePrompt.clean(response.text, original: text)
            guard !cleaned.trimmedWhitespace.isEmpty else { throw RewriteError.failed("\(name) returned an empty rewrite") }
            return cleaned
        case .failure(let error):
            throw error.rewriteError(for: endpoint)
        }
    }
}
