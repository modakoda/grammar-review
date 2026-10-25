import Foundation

struct LSPLineIndex: Sendable {
    private var starts: [Int] = [0]
    private var ends: [Int] = []

    init(_ text: String) {
        let units = Array(text.utf16)
        var index = 0
        while index < units.count {
            switch units[index] {
            case 0x0A:
                ends.append(index)
                starts.append(index + 1)
            case 0x0D:
                ends.append(index)
                if index + 1 < units.count, units[index + 1] == 0x0A { index += 1 }
                starts.append(index + 1)
            default:
                break
            }
            index += 1
        }
        ends.append(units.count)
    }

    func offset(of position: LSPPosition) -> Int? {
        guard position.line >= 0, position.character >= 0, position.line < starts.count else { return nil }
        return min(starts[position.line] + position.character, ends[position.line])
    }

    func utf16Range(of range: LSPRange) -> NSRange? {
        guard let start = offset(of: range.start), let end = offset(of: range.end), end >= start else { return nil }
        return NSRange(location: start, length: end - start)
    }
}
