import Foundation

public protocol ToneDetecting: AnyObject, Sendable {
    func detectTone(_ text: String, settings: AppSettings) async throws -> ToneReport
}
