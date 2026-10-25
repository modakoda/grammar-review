import ApplicationServices
import Foundation

nonisolated enum FieldTarget: Equatable, Sendable {
    case focusedElement
    case ancestor(AncestorKind)
}

nonisolated enum FieldRejection: String, Equatable, Sendable {
    case noElement
    case unresponsive
    case secure
    case secureInput
    case disabled
    case notEditable
}

nonisolated enum FieldDecision: Equatable, Sendable {
    case accept(FieldTarget)
    case reject(FieldRejection)

    var isTransient: Bool {
        switch self {
        case .reject(.unresponsive), .reject(.secureInput): true
        default: false
        }
    }
}
