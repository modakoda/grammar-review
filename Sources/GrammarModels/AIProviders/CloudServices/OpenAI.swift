import Foundation

public extension CloudService {
    static let openAI = CloudService(
        id: "openai",
        name: "OpenAI",
        assistantName: "GPT",
        baseURL: URL(string: "https://api.openai.com/v1")!,
        consoleURL: URL(string: "https://platform.openai.com/settings/organization/api-keys")!,
        keyHint: "sk-…",
        environmentVariable: "OPENAI_API_KEY",
        models: [
            AIModelOption(
                id: "gpt-6-luna",
                name: "GPT-6 Luna",
                detail: "Fast and cheap. Recommended for as-you-type checks.",
                pricing: ModelPricing(input: 0.10, output: 0.50, cacheWrite: 0.125, cacheRead: 0.01),
                style: CloudService.RequestStyle(
                    structuredOutput: .jsonSchema,
                    outputLimit: .maxCompletionTokens,
                    systemRole: "developer",
                    reasoningEffort: "none"
                )
            ),
            AIModelOption(
                id: "gpt-6.1-sol",
                name: "GPT-6.1 Sol",
                detail: "Better style and clarity suggestions; thinks briefly, so slower and dearer.",
                pricing: ModelPricing(input: 2.00, output: 10.00, cacheWrite: 2.50, cacheRead: 0.10)
            ),
            AIModelOption(
                id: "gpt-6-astra",
                name: "GPT-6 Astra",
                detail: "Highest quality; slowest and most expensive.",
                pricing: ModelPricing(input: 10.00, output: 50.00, cacheWrite: 12.50, cacheRead: 1.00)
            ),
        ],
        defaultModel: "gpt-6-luna",
        style: CloudService.RequestStyle(
            structuredOutput: .jsonSchema,
            outputLimit: .maxCompletionTokens,
            systemRole: "developer",
            reasoningEffort: "low"
        ),
        listsModels: true,
        notes: "Uses your OpenAI account and key. GPT-6 Luna is quick enough to check as you type; GPT-6.1 Sol gives better style suggestions."
    )
}
