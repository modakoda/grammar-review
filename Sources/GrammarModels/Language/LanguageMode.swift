import Foundation

public enum LanguageMode: Codable, Sendable, Hashable {
    case automatic
    case keyboard
    case fixed(String)
}
