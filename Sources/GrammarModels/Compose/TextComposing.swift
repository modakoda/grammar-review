import Foundation

public protocol TextComposing: AnyObject, Sendable {
    func compose(_ request: String, context: String?, settings: AppSettings) async throws -> String
}
