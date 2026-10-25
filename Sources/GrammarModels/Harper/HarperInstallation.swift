import Foundation

public enum HarperInstallation: Sendable, Equatable {
    case found(path: String, version: String)
    case notFound
    case unusable(path: String, reason: String)
}
