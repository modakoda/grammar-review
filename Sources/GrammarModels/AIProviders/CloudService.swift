import Foundation

public struct CloudService: Sendable, Hashable, Identifiable {
    public struct RequestStyle: Sendable, Hashable {
        public enum StructuredOutput: Sendable, Hashable {
            case jsonSchema
            case jsonObject
            case none
        }

        public enum OutputLimit: Sendable, Hashable {
            case maxTokens
            case maxCompletionTokens
        }

        public var structuredOutput: StructuredOutput
        public var outputLimit: OutputLimit
        public var systemRole: String
        public var reasoningEffort: String?

        public init(
            structuredOutput: StructuredOutput = .jsonSchema,
            outputLimit: OutputLimit = .maxTokens,
            systemRole: String = "system",
            reasoningEffort: String? = nil
        ) {
            self.structuredOutput = structuredOutput
            self.outputLimit = outputLimit
            self.systemRole = systemRole
            self.reasoningEffort = reasoningEffort
        }

        public static let standard = RequestStyle()
    }

    public let id: String
    public let name: String
    public let assistantName: String
    public let baseURL: URL
    public let consoleURL: URL
    public let keyHint: String
    public let environmentVariable: String
    public let models: [AIModelOption]
    public let defaultModel: String
    public let style: RequestStyle
    public let listsModels: Bool
    public let notes: String

    public init(
        id: String,
        name: String,
        assistantName: String,
        baseURL: URL,
        consoleURL: URL,
        keyHint: String,
        environmentVariable: String,
        models: [AIModelOption],
        defaultModel: String,
        style: RequestStyle = .standard,
        listsModels: Bool = true,
        notes: String
    ) {
        self.id = id
        self.name = name
        self.assistantName = assistantName
        self.baseURL = baseURL
        self.consoleURL = consoleURL
        self.keyHint = keyHint
        self.environmentVariable = environmentVariable
        self.models = models
        self.defaultModel = defaultModel
        self.style = style
        self.listsModels = listsModels
        self.notes = notes
    }

    public static let all: [CloudService] = [.openAI, .xai, .gemini, .mistral, .deepseek]

    public static func find(_ id: String) -> CloudService? {
        all.first { $0.id == id }
    }

    public func option(for model: String) -> AIModelOption? {
        models.first { $0.id == model }
    }

    public func style(for model: String) -> RequestStyle {
        option(for: model)?.style ?? style
    }

    public func pricing(for model: String) -> ModelPricing? {
        option(for: model)?.pricing
    }

    public static func == (lhs: CloudService, rhs: CloudService) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
