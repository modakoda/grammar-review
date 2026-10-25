import Foundation

public protocol AppUpdater: AnyObject {
    var canCheckForUpdates: Bool { get }
    var automaticallyChecksForUpdates: Bool { get set }
    var pendingUpdateVersion: String? { get }
    func checkForUpdates()
}

nonisolated public struct UpdaterConfiguration: Equatable, Sendable {
    public let feedURL: URL?

    public init(info: [String: Any]?) {
        guard
            let feed = info?["SUFeedURL"] as? String,
            let url = URL(string: feed),
            url.scheme?.lowercased() == "https",
            url.host?.isEmpty == false,
            Self.isPublicKey(info?["SUPublicEDKey"] as? String)
        else {
            feedURL = nil
            return
        }
        feedURL = url
    }

    public static var current: UpdaterConfiguration {
        UpdaterConfiguration(info: Bundle.main.infoDictionary)
    }

    public var isEnabled: Bool { feedURL != nil }

    static func isPublicKey(_ key: String?) -> Bool {
        guard let key, let data = Data(base64Encoded: key) else { return false }
        return data.count == 32
    }
}
