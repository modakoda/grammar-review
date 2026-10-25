import Foundation

public enum ComposeInsertion {
    public enum Style: Sendable {
        case paragraph
        case inline
    }

    public static func style(for text: String) -> Style {
        text.contains(where: \.isNewline) ? .paragraph : .inline
    }

    public static func text(_ composed: String, at range: NSRange, in text: String, as style: Style) -> String {
        let ns = text as NSString
        guard range.length == 0, ns.length > 0, range.location <= ns.length else {
            return style == .inline ? oneLine(composed) : composed
        }
        switch style {
        case .paragraph: return paragraph(composed, at: range.location, in: ns)
        case .inline: return inline(composed, at: range.location, in: ns)
        }
    }

    private static func paragraph(_ composed: String, at location: Int, in ns: NSString) -> String {
        func isNewline(_ index: Int) -> Bool { isMember(ns, index, of: .newlines) }
        var result = composed
        if location > 0, !isNewline(location - 1) {
            result = "\n\n" + result
        } else if location > 1, !isNewline(location - 2) {
            result = "\n" + result
        }
        if location < ns.length, !isNewline(location) {
            result += "\n\n"
        } else if location + 1 < ns.length, !isNewline(location + 1) {
            result += "\n"
        }
        return result
    }

    private static func inline(_ composed: String, at location: Int, in ns: NSString) -> String {
        var result = oneLine(composed)
        if location > 0, !isMember(ns, location - 1, of: .whitespacesAndNewlines) { result = " " + result }
        if location < ns.length, !isMember(ns, location, of: .whitespacesAndNewlines) { result += " " }
        return result
    }

    private static func oneLine(_ text: String) -> String {
        text.split(whereSeparator: \.isNewline).joined(separator: " ")
    }

    private static func isMember(_ ns: NSString, _ index: Int, of set: CharacterSet) -> Bool {
        guard let scalar = UnicodeScalar(ns.character(at: index)) else { return false }
        return set.contains(scalar)
    }
}
