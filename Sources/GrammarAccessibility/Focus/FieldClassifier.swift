import ApplicationServices
import Foundation

nonisolated enum FieldClassifier {
    static let textRoles: Set<String> = [kAXTextAreaRole, kAXTextFieldRole, kAXComboBoxRole, "AXSearchField"]
    static let singleLineRoles: Set<String> = [kAXTextFieldRole, kAXComboBoxRole, "AXSearchField"]
    static let secureRoles: Set<String> = [kAXSecureTextFieldSubrole]
    static let nonTextRoles: Set<String> = [
        kAXButtonRole, kAXCheckBoxRole, kAXRadioButtonRole, kAXSliderRole, kAXPopUpButtonRole,
        kAXMenuButtonRole, kAXIncrementorRole, kAXScrollBarRole, kAXDisclosureTriangleRole,
        kAXColorWellRole, kAXImageRole, kAXMenuItemRole, kAXMenuBarItemRole, kAXValueIndicatorRole,
        kAXLevelIndicatorRole, kAXProgressIndicatorRole, kAXStaticTextRole, "AXDateField", "AXTimeField",
    ]
    static let passwordHints = ["password", "passcode", "passphrase", "passwort", "contraseña", "mot de passe", "slaptažod"]

    static func classify(_ snapshot: FieldSnapshot) -> FieldDecision {
        switch snapshot.readFailure {
        case .gone: return .reject(.noElement)
        case .unresponsive: return .reject(.unresponsive)
        case nil: break
        }
        if isSecure(snapshot) { return .reject(.secure) }
        if snapshot.ancestors.contains(where: { isSecure($0.snapshot) }) { return .reject(.secure) }
        if snapshot.isEnabled == false { return .reject(.disabled) }

        let accepted: FieldTarget? = if isDirectlyEditable(snapshot) {
            .focusedElement
        } else {
            editableAncestor(in: snapshot)
        }
        guard let accepted else { return .reject(.notEditable) }
        if snapshot.secureInputActive { return .reject(.secureInput) }
        return .accept(accepted)
    }

    static func isSecure(_ snapshot: FieldSnapshot) -> Bool {
        if isSecure(role: snapshot.role, subrole: snapshot.subrole, roleDescription: snapshot.roleDescription) {
            return true
        }
        guard let role = snapshot.role, singleLineRoles.contains(role) else { return false }
        return snapshot.hints.contains { hint in passwordHints.contains { hint.contains($0) } }
    }

    static func isSecure(role: String?, subrole: String?, roleDescription: String?) -> Bool {
        if let subrole, secureRoles.contains(subrole) { return true }
        if let role, secureRoles.contains(role) { return true }
        if let description = roleDescription?.lowercased(),
           description.contains("secure text") || description.contains("password") {
            return true
        }
        return false
    }

    static func isDirectlyEditable(_ snapshot: FieldSnapshot) -> Bool {
        guard snapshot.isEnabled != false else { return false }
        let role = snapshot.role ?? ""
        let isSearchField = snapshot.subrole == kAXSearchFieldSubrole
        if textRoles.contains(role) || isSearchField {
            if snapshot.isValueSettable == false, snapshot.isSelectedTextSettable != true { return false }
            return true
        }
        if nonTextRoles.contains(role) { return false }
        return snapshot.valueIsString == true && snapshot.isValueSettable == true
    }

    private static func editableAncestor(in snapshot: FieldSnapshot) -> FieldTarget? {
        for kind in AncestorKind.allCases {
            guard let ancestor = snapshot.ancestors.first(where: { $0.kind == kind })?.snapshot,
                  ancestor.readFailure == nil, ancestor.isEnabled != false
            else { continue }
            switch kind {
            case .editable, .highestEditable:
                return .ancestor(kind)
            case .focusable:
                if isDirectlyEditable(ancestor) { return .ancestor(kind) }
            }
        }
        return nil
    }
}
