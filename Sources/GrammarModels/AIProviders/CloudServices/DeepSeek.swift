import Foundation

public extension CloudService {
    static let deepseek = CloudService(
        id: "deepseek",
        name: "DeepSeek",
        assistantName: "DeepSeek",
        baseURL: URL(string: "https://api.deepseek.com")!,
        consoleURL: URL(string: "https://platform.deepseek.com/api_keys")!,
        keyHint: "sk-…",
        environmentVariable: "DEEPSEEK_API_KEY",
        models: [
            AIModelOption(
                id: "deepseek-flash",
                name: "DeepSeek V4.1 Flash",
                detail: "Fast and very cheap. Recommended for as-you-type checks.",
                pricing: ModelPricing(input: 0.30, output: 1.20, cacheRead: 0.006)
            ),
            AIModelOption(
                id: "deepseek-v4-pro",
                name: "DeepSeek V4 Pro",
                detail: "Better style and clarity suggestions; slower and dearer.",
                pricing: ModelPricing(input: 1.32, output: 3.96, cacheRead: 0.044)
            ),
        ],
        defaultModel: "deepseek-flash",
        style: CloudService.RequestStyle(
            structuredOutput: .jsonObject,
            outputLimit: .maxTokens,
            systemRole: "system",
            reasoningEffort: "none"
        ),
        listsModels: true,
        notes: "Uses your DeepSeek account and key. Very cheap, and half price off-peak; answers can take a few seconds at busy times. Read its data policy before sending confidential text."
    )
}
