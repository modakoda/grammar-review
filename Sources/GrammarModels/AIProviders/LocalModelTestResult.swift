import Foundation

public struct LocalModelTestResult: Sendable, Equatable {
    public var duration: Duration
    public var suggestionCount: Int

    public init(duration: Duration, suggestionCount: Int) {
        self.duration = duration
        self.suggestionCount = suggestionCount
    }
}
