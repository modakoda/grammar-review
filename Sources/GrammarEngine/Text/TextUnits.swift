import Foundation

enum TextUnits {
    static func isHighSurrogate(_ unit: UInt16) -> Bool { (0xD800...0xDBFF).contains(unit) }
    static func isLowSurrogate(_ unit: UInt16) -> Bool { (0xDC00...0xDFFF).contains(unit) }

    static func isWordCharacter(_ string: NSString, at index: Int) -> Bool {
        guard index >= 0, index < string.length else { return false }
        let range = string.rangeOfComposedCharacterSequence(at: index)
        guard let scalar = string.substring(with: range).unicodeScalars.first else { return false }
        return isWordScalar(scalar)
    }

    static func isWordScalar(_ scalar: Unicode.Scalar) -> Bool {
        CharacterSet.alphanumerics.contains(scalar) || scalar == "'" || scalar == "\u{2019}"
    }

    static func isAligned(_ range: NSRange, in string: NSString) -> Bool {
        guard range.location != NSNotFound, range.location >= 0, range.length >= 0,
              NSMaxRange(range) <= string.length else { return false }
        guard range.length > 0 else { return true }
        return string.rangeOfComposedCharacterSequences(for: range) == range
    }

    static func substring(_ string: NSString, _ range: NSRange) -> String? {
        guard range.location != NSNotFound, range.location >= 0, range.length >= 0,
              NSMaxRange(range) <= string.length else { return nil }
        return string.substring(with: range)
    }

    static func overlaps(_ a: NSRange, _ b: NSRange) -> Bool {
        a.location < NSMaxRange(b) && b.location < NSMaxRange(a)
    }
}

extension String {
    var trimmedWhitespace: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
