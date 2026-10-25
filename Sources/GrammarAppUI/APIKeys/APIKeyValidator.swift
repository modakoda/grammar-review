import Foundation

public typealias APIKeyValidator = (_ key: String, _ model: String) async throws -> Void
