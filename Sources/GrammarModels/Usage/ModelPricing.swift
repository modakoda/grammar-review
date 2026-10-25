import Foundation

public struct ModelPricing: Sendable, Hashable {
    public var input: Double
    public var output: Double
    public var cacheWrite: Double
    public var cacheRead: Double

    public init(input: Double, output: Double, cacheWrite: Double? = nil, cacheRead: Double? = nil) {
        self.input = input
        self.output = output
        self.cacheWrite = cacheWrite ?? input
        self.cacheRead = cacheRead ?? input
    }

    static let byModel: [String: ModelPricing] = [
        "claude-haiku-5-5": ModelPricing(input: 0.10, output: 0.50, cacheWrite: 0.125, cacheRead: 0.01),
        "claude-sonnet-5-5": ModelPricing(input: 2, output: 10, cacheWrite: 2.5, cacheRead: 0.10),
        "claude-opus-5-5": ModelPricing(input: 4, output: 20, cacheWrite: 5, cacheRead: 0.20),
        "claude-sonnet-5": ModelPricing(input: 2, output: 10, cacheWrite: 2.5, cacheRead: 0.20),
        "claude-opus-5": ModelPricing(input: 5, output: 25, cacheWrite: 6.25, cacheRead: 0.50),
        "claude-opus-4-8": ModelPricing(input: 5, output: 25, cacheWrite: 6.25, cacheRead: 0.50),
        "claude-fable-5-1": ModelPricing(input: 10, output: 50, cacheWrite: 12.5, cacheRead: 0.25),
    ]

    public static func forModel(_ model: String) -> ModelPricing? {
        byModel[model]
    }

    public func cost(of usage: TokenUsage) -> Double {
        (Double(usage.input) * input + Double(usage.output) * output
            + Double(usage.cacheWrite) * cacheWrite + Double(usage.cacheRead) * cacheRead) / 1_000_000
    }
}
