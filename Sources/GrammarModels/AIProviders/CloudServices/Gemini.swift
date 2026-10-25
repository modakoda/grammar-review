import Foundation

public extension CloudService {
    static let gemini = CloudService(
        id: "gemini",
        name: "Google Gemini",
        assistantName: "Gemini",
        baseURL: URL(string: "https://generativelanguage.googleapis.com/v1beta/openai")!,
        consoleURL: URL(string: "https://aistudio.google.com/apikey")!,
        keyHint: "AIza…",
        environmentVariable: "GEMINI_API_KEY",
        models: [
            AIModelOption(
                id: "gemini-3.5-flash-lite",
                name: "Gemini 3.5 Flash-Lite",
                detail: "Fast and cheap. Recommended for as-you-type checks.",
                pricing: ModelPricing(input: 0.30, output: 2.50, cacheRead: 0.03)
            ),
            AIModelOption(
                id: "gemini-3.1-flash-lite",
                name: "Gemini 3.1 Flash-Lite",
                detail: "The cheapest; a generation older.",
                pricing: ModelPricing(input: 0.25, output: 1.50, cacheRead: 0.025)
            ),
            AIModelOption(
                id: "gemini-3.8-flash",
                name: "Gemini 3.8 Flash",
                detail: "Better style and clarity suggestions; slower. Prices rise on 1 January 2027.",
                pricing: ModelPricing(input: 0.75, output: 3.75, cacheRead: 0.075)
            ),
            AIModelOption(
                id: "gemini-4-argon",
                name: "Gemini 4 Argon",
                detail: "Google's flagship: the best suggestions, the slowest and dearest. No free tier.",
                pricing: ModelPricing(input: 2.00, output: 10.00, cacheRead: 0.10)
            ),
        ],
        defaultModel: "gemini-3.5-flash-lite",
        style: CloudService.RequestStyle(
            structuredOutput: .jsonSchema,
            outputLimit: .maxTokens,
            systemRole: "system",
            reasoningEffort: "low"
        ),
        listsModels: true,
        notes: "Uses your Google AI Studio key. Flash-Lite is quick enough to check as you type. The free tier is rate-limited "
            + "and lets Google use your text to improve its products; a billing account turns that off."
    )
}
