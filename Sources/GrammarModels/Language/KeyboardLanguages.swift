import Carbon
import Foundation

public struct KeyboardLanguages: Sendable, Equatable {
    public var current: String?
    public var enabled: [String]

    public init(current: String? = nil, enabled: [String] = []) {
        self.current = current
        self.enabled = enabled
    }

    public static let didChangeNotification = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)

    @MainActor public static func read() -> KeyboardLanguages {
        let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        let filter = [
            kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
            kTISPropertyInputSourceIsSelectCapable as String: true,
        ] as CFDictionary
        let sources = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] ?? []
        var enabled: [String] = []
        for language in sources.compactMap(primaryLanguage) where !enabled.contains(language) {
            enabled.append(language)
        }
        return KeyboardLanguages(current: current.flatMap(primaryLanguage), enabled: enabled)
    }

    @MainActor private static func primaryLanguage(of source: TISInputSource) -> String? {
        guard let pointer = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) else { return nil }
        let languages = Unmanaged<CFArray>.fromOpaque(pointer).takeUnretainedValue() as? [String]
        guard let first = languages?.first, !first.isEmpty else { return nil }
        return first
    }

    public func userLanguages(preferred: [String]) -> [String] {
        var result: [String] = []
        for code in [current].compactMap(\.self) + enabled + preferred {
            let language = Self.withoutRegion(code)
            guard !language.isEmpty, !result.contains(where: { Self.isSameLanguage($0, language) }) else { continue }
            result.append(language)
        }
        return result
    }

    public static func withoutRegion(_ code: String) -> String {
        let parts = code.split(whereSeparator: { $0 == "-" || $0 == "_" })
        guard let language = parts.first else { return "" }
        if parts.count > 1, parts[1].count == 4, parts[1].allSatisfy(\.isLetter) {
            return "\(language)-\(parts[1])"
        }
        return String(language)
    }

    public static func isSameLanguage(_ lhs: String, _ rhs: String) -> Bool {
        baseLanguage(lhs).caseInsensitiveCompare(baseLanguage(rhs)) == .orderedSame
    }

    public static func baseLanguage(_ code: String) -> String {
        String(code.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? Substring(code))
    }
}
