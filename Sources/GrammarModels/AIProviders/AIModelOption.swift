import Foundation

public struct AIModelOption: Sendable, Hashable, Identifiable {
    public var id: String
    public var name: String
    public var detail: String
    public var pricing: ModelPricing?
    public var style: CloudService.RequestStyle?

    public init(id: String, name: String, detail: String, pricing: ModelPricing? = nil, style: CloudService.RequestStyle? = nil) {
        self.id = id
        self.name = name
        self.detail = detail
        self.pricing = pricing
        self.style = style
    }

    public static let all: [AIModelOption] = [
        AIModelOption(id: "claude-haiku-5-5", name: "Claude Haiku 5.5", detail: "Fastest and cheapest. Recommended for as-you-type checks."),
        AIModelOption(id: "claude-sonnet-5-5", name: "Claude Sonnet 5.5", detail: "Better style and clarity suggestions; slower."),
        AIModelOption(id: "claude-opus-5-5", name: "Claude Opus 5.5", detail: "Highest quality; slowest and most expensive."),
    ]
}
