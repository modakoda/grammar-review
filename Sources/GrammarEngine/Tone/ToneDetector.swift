import Foundation
import GrammarModels

struct ToneDetector: Sendable {
    let backends: AIBackends
    let endpoints: EndpointResolver
    let languages: LanguageSource

    func detectTone(_ text: String, settings: AppSettings) async throws -> ToneReport {
        let sample = TonePrompt.sample(text)
        guard !sample.isEmpty else { throw RewriteError.failed("Write some text first") }
        let endpoint = try await endpoints.require(settings)
        let language = await languages.resolver(for: settings).language(of: sample)
        let request = TonePrompt.request(text: sample, language: language, model: endpoint.model)
        Log.engine.debug("Tone detection of \(sample.utf16.count, privacy: .public) units")
        switch await backends.send(request, to: endpoint).flatMap(TonePrompt.parse) {
        case .success(let report):
            return report
        case .failure(let error):
            throw error.rewriteError(for: endpoint)
        }
    }
}
