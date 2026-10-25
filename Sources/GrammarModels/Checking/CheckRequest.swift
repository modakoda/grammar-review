import Foundation

public struct CheckRequest: Sendable, Equatable {
    public var text: String
    public var bundleID: String?
    public var settings: AppSettings
    public var goals: WritingGoals

    public init(text: String, bundleID: String?, settings: AppSettings, goals: WritingGoals = .none) {
        self.text = text
        self.bundleID = bundleID
        self.settings = settings
        self.goals = goals
    }
}
