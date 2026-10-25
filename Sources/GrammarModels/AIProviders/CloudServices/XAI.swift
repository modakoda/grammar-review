import Foundation

public extension CloudService {
    static let xai = CloudService(
        id: "xai",
        name: "xAI (Grok)",
        assistantName: "Grok",
        baseURL: URL(string: "https://api.x.ai/v1")!,
        consoleURL: URL(string: "https://console.x.ai/team/default/api-keys")!,
        keyHint: "xai-…",
        environmentVariable: "XAI_API_KEY",
        models: [
            AIModelOption(
                id: "grok-4.3",
                name: "Grok 4.3",
                detail: "Fast and the cheapest. Recommended for as-you-type checks.",
                pricing: ModelPricing(input: 1.25, output: 2.50, cacheRead: 0.20)
            ),
            AIModelOption(
                id: "grok-4.5",
                name: "Grok 4.5",
                detail: "Stronger reasoning for hard sentences; slower and dearer.",
                pricing: ModelPricing(input: 2.00, output: 6.00, cacheRead: 0.30)
            ),
            AIModelOption(
                id: "grok-4.7",
                name: "Grok 4.7",
                detail: "xAI's frontier model: the best style suggestions, the slowest.",
                pricing: ModelPricing(input: 2.00, output: 6.00, cacheRead: 0.50)
            ),
        ],
        defaultModel: "grok-4.3",
        style: CloudService.RequestStyle(
            structuredOutput: .jsonSchema,
            outputLimit: .maxCompletionTokens,
            systemRole: "system",
            reasoningEffort: "low"
        ),
        listsModels: true,
        notes: "Uses your xAI account and key. Grok 4.3 is quick enough to check as you type; Grok 4.5 and 4.7 think longer and cost more."
    )
}
