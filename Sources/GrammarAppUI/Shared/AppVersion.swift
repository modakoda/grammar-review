import Foundation

nonisolated enum AppVersion {
    static func description(info: [String: Any]?) -> String {
        let short = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String
        switch (short, build) {
        case let (short?, build?) where build != short:
            return "Version \(short) (\(build))"
        case let (short?, _):
            return "Version \(short)"
        default:
            return "Development build"
        }
    }

    static var current: String {
        description(info: Bundle.main.infoDictionary)
    }

    static var copyright: String? {
        Bundle.main.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String
    }
}
