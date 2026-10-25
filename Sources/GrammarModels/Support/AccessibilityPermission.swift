import ApplicationServices
import Foundation

public enum AccessibilityPermission {
    public static var isTrusted: Bool { AXIsProcessTrusted() }

    @discardableResult
    public static func requestIfNeeded() -> Bool {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
}
