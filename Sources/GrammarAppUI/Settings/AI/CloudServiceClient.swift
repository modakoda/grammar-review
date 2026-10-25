import Foundation
import GrammarModels

public struct CloudServiceClient {
    public var validateKey: (_ service: CloudService, _ key: String, _ model: String) async throws -> Void
    public var listModels: (_ service: CloudService, _ key: String) async throws -> [String]
    public var testModel: (_ service: CloudService, _ model: String, _ key: String) async throws -> LocalModelTestResult

    public init(
        validateKey: @escaping (_ service: CloudService, _ key: String, _ model: String) async throws -> Void,
        listModels: @escaping (_ service: CloudService, _ key: String) async throws -> [String],
        testModel: @escaping (_ service: CloudService, _ model: String, _ key: String) async throws -> LocalModelTestResult
    ) {
        self.validateKey = validateKey
        self.listModels = listModels
        self.testModel = testModel
    }
}
