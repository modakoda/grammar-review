import ApplicationServices
import Foundation

nonisolated struct FieldSnapshot: Equatable, Sendable {
    enum ReadFailure: Equatable, Sendable {
        case gone
        case unresponsive
    }

    var role: String?
    var subrole: String?
    var roleDescription: String?
    var isEnabled: Bool?
    var isValueSettable: Bool?
    var isSelectedTextSettable: Bool?
    var valueIsString: Bool?
    var hints: [String] = []
    var secureInputActive = false
    var readFailure: ReadFailure?
    var ancestors: [FieldAncestor] = []

    init(
        role: String? = nil,
        subrole: String? = nil,
        roleDescription: String? = nil,
        isEnabled: Bool? = nil,
        isValueSettable: Bool? = nil,
        isSelectedTextSettable: Bool? = nil,
        valueIsString: Bool? = nil,
        hints: [String] = [],
        secureInputActive: Bool = false,
        readFailure: ReadFailure? = nil,
        ancestors: [FieldAncestor] = []
    ) {
        self.role = role
        self.subrole = subrole
        self.roleDescription = roleDescription
        self.isEnabled = isEnabled
        self.isValueSettable = isValueSettable
        self.isSelectedTextSettable = isSelectedTextSettable
        self.valueIsString = valueIsString
        self.hints = hints
        self.secureInputActive = secureInputActive
        self.readFailure = readFailure
        self.ancestors = ancestors
    }
}

nonisolated enum AncestorKind: String, Sendable, CaseIterable {
    case editable
    case highestEditable
    case focusable

    var attribute: String {
        switch self {
        case .editable: AXName.editableAncestor
        case .highestEditable: AXName.highestEditableAncestor
        case .focusable: AXName.focusableAncestor
        }
    }
}

nonisolated struct FieldAncestor: Equatable, Sendable {
    var kind: AncestorKind
    var snapshot: FieldSnapshot

    init(_ kind: AncestorKind, _ snapshot: FieldSnapshot) {
        self.kind = kind
        self.snapshot = snapshot
    }
}
