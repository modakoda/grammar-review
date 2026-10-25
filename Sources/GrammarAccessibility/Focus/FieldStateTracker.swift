import Foundation

nonisolated struct FieldStateTracker: Sendable {
    struct Changes: OptionSet, Sendable {
        let rawValue: Int
        static let text = Changes(rawValue: 1 << 0)
        static let selection = Changes(rawValue: 1 << 1)
        static let geometry = Changes(rawValue: 1 << 2)
    }

    static let frameTolerance: CGFloat = 0.5

    private(set) var text: String?
    private(set) var selection: NSRange?
    private(set) var frame: CGRect?

    init() {}

    mutating func reset(text: String? = nil, selection: NSRange? = nil, frame: CGRect? = nil) {
        self.text = text
        self.selection = selection
        self.frame = frame
    }

    mutating func update(text: String?, selection: NSRange?, frame: CGRect?) -> Changes {
        var changes: Changes = []
        if let text, updateText(text) { changes.insert(.text) }
        if let selection, updateSelection(selection) { changes.insert(.selection) }
        if let frame, updateFrame(frame) { changes.insert(.geometry) }
        return changes
    }

    mutating func updateText(_ newText: String) -> Bool {
        guard newText != text else { return false }
        text = newText
        return true
    }

    mutating func updateSelection(_ newSelection: NSRange) -> Bool {
        guard newSelection != selection else { return false }
        selection = newSelection
        return true
    }

    mutating func updateFrame(_ newFrame: CGRect) -> Bool {
        if let frame, Self.isClose(frame, newFrame) { return false }
        frame = newFrame
        return true
    }

    static func isClose(_ a: CGRect, _ b: CGRect) -> Bool {
        if a.isNull || b.isNull { return a.isNull && b.isNull }
        return abs(a.minX - b.minX) < frameTolerance && abs(a.minY - b.minY) < frameTolerance
            && abs(a.width - b.width) < frameTolerance && abs(a.height - b.height) < frameTolerance
    }
}
