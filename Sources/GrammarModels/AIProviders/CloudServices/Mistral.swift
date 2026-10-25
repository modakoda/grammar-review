import Foundation

public extension CloudService {
    static let mistral = CloudService(
        id: "mistral",
        name: "Mistral",
        assistantName: "Mistral",
        baseURL: URL(string: "https://api.mistral.ai/v1")!,
        consoleURL: URL(string: "https://console.mistral.ai/api-keys")!,
        keyHint: "API key",
        environmentVariable: "MISTRAL_API_KEY",
        models: [
            AIModelOption(
                id: "mistral-small-latest",
                name: "Mistral Small 4",
                detail: "Fast and cheap, strong in European languages. Recommended for as-you-type checks.",
                pricing: ModelPricing(input: 0.15, output: 0.60, cacheRead: 0.015)
            ),
            AIModelOption(
                id: "ministral-8b-latest",
                name: "Ministral 3 8B",
                detail: "The cheapest and quickest; misses more in languages other than English.",
                pricing: ModelPricing(input: 0.15, output: 0.15, cacheRead: 0.015)
            ),
            AIModelOption(
                id: "mistral-medium-latest",
                name: "Mistral Medium 3.5",
                detail: "Better style and clarity suggestions; slower and dearer.",
                pricing: ModelPricing(input: 1.50, output: 7.50, cacheRead: 0.15)
            ),
            AIModelOption(
                id: "mistral-large-latest",
                name: "Mistral Large 4",
                detail: "Mistral's largest model; the best suggestions, the slowest.",
                pricing: ModelPricing(input: 1.36, output: 4.18, cacheRead: 0.14)
            ),
        ],
        defaultModel: "mistral-small-latest",
        style: CloudService.RequestStyle(
            structuredOutput: .jsonSchema,
            outputLimit: .maxTokens,
            systemRole: "system",
            reasoningEffort: "none"
        ),
        listsModels: true,
        notes: "Uses your Mistral account and key, with servers in the EU. Mistral Small is quick enough to check as you type."
    )
}
