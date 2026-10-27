import Foundation

public enum FieldKind: String, Codable, Sendable, CaseIterable, Identifiable {
    case input
    case textArea

    public init(isSingleLine: Bool) {
        self = isSingleLine ? .input : .textArea
    }

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .input: "Input fields"
        case .textArea: "Text areas"
        }
    }
}

public enum BadgePlacement: String, Codable, Sendable, CaseIterable, Identifiable {
    case automatic
    case insideBottomRight = "inside"
    case insideTopRight
    case insideBottomLeft
    case insideTopLeft
    case right
    case left
    case above
    case below

    public var id: String { rawValue }

    public var isInside: Bool {
        switch self {
        case .insideBottomRight, .insideTopRight, .insideBottomLeft, .insideTopLeft: true
        case .automatic, .right, .left, .above, .below: false
        }
    }

    public var displayName: String {
        switch self {
        case .automatic: "Automatic"
        case .insideBottomRight: "Inside, bottom right"
        case .insideTopRight: "Inside, top right"
        case .insideBottomLeft: "Inside, bottom left"
        case .insideTopLeft: "Inside, top left"
        case .right: "Right of the field"
        case .left: "Left of the field"
        case .above: "Above the field"
        case .below: "Below the field"
        }
    }

    public func detail(for kind: FieldKind) -> String {
        switch (self, kind) {
        case (.automatic, _): "Left of the field, so it doesn't cover what you type."
        case (.insideBottomRight, .input), (.insideTopRight, .input): "It can cover the end of the text."
        case (.insideBottomLeft, .input), (.insideTopLeft, .input): "It can cover the start of the text."
        case (.insideBottomRight, .textArea): "It can cover the end of the last line."
        case (.insideTopRight, .textArea): "It can cover the end of the first line."
        case (.insideBottomLeft, .textArea): "It can cover the start of the last line."
        case (.insideTopLeft, .textArea): "It can cover the start of the first line."
        case (.right, _): "It can cover a button beside the field."
        case (.left, _): "It can cover a label beside the field."
        case (.above, _): "It can cover what's above the field."
        case (.below, _): "It can cover what's under the field."
        }
    }
}
