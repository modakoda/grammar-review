import Foundation
import GrammarModels

protocol GrammarAIService: Sendable {
    func proofread(paragraph: String, language: String?, goals: WritingGoals, endpoint: AIEndpoint) async -> Result<[AIEdit], AIError>
}

struct PromptGrammarService: GrammarAIService {
    let backends: AIBackends

    func proofread(paragraph: String, language: String?, goals: WritingGoals, endpoint: AIEndpoint) async -> Result<[AIEdit], AIError> {
        let request = CheckPrompt.request(paragraph: paragraph, language: language, goals: goals, model: endpoint.model)
        return await backends.send(request, to: endpoint).flatMap(CheckPrompt.parse)
    }
}
