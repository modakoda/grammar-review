import ApplicationServices
import Foundation

nonisolated enum AppFamily: String, Sendable {
    case native
    case webKit
    case chromium
    case electron
}

nonisolated enum ManualAccessibilityResult: String, Sendable {
    case applied
    case unsupported
    case failed
}

nonisolated enum WebContentProbe: String, Sendable {
    case exposed
    case empty
    case unknown
}

nonisolated enum AppCompatibility {
    static let chromiumBundleIDPrefixes = [
        "com.google.Chrome",
        "com.brave.Browser",
        "com.microsoft.edgemac",
        "com.vivaldi.Vivaldi",
        "com.operasoftware.Opera",
        "com.operasoftware.OperaGX",
        "org.chromium.Chromium",
        "company.thebrowser.Browser",
        "company.thebrowser.dia",
    ]

    static let webKitBundleIDPrefixes = [
        "com.apple.Safari",
        "com.apple.SafariTechnologyPreview",
        "com.kagi.kagimacOS",
    ]

    static func isChromiumBrowser(_ bundleID: String?) -> Bool {
        matches(bundleID, chromiumBundleIDPrefixes)
    }

    static func family(bundleID: String?, isElectron: Bool) -> AppFamily {
        if isElectron { return .electron }
        if isChromiumBrowser(bundleID) { return .chromium }
        if matches(bundleID, webKitBundleIDPrefixes) { return .webKit }
        return .native
    }

    static func isElectronApp(at bundleURL: URL?) -> Bool {
        guard let bundleURL else { return false }
        let framework = bundleURL.appendingPathComponent("Contents/Frameworks/Electron Framework.framework")
        return FileManager.default.fileExists(atPath: framework.path)
    }

    static func needsEnhancedUserInterface(family: AppFamily, manual: ManualAccessibilityResult, probe: WebContentProbe?) -> Bool {
        guard family == .chromium else { return false }
        if manual != .applied { return true }
        return probe == .empty
    }

    private static func matches(_ bundleID: String?, _ prefixes: [String]) -> Bool {
        guard let bundleID else { return false }
        return prefixes.contains { bundleID == $0 || bundleID.hasPrefix($0 + ".") }
    }
}
