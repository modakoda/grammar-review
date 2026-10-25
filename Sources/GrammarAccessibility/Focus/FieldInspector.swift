import ApplicationServices
import Foundation

nonisolated enum FieldInspector {
    struct Inspection {
        var decision: FieldDecision
        var target: AXElement?
        var role: String?
    }

    static func inspect(_ element: AXElement, appPID: pid_t) -> Inspection {
        let secureInput = SecureInput.ownerPID() == appPID
        var snapshot = basicSnapshot(of: element, secureInputActive: secureInput)
        var decision = FieldClassifier.classify(snapshot)
        var ancestorElements: [AncestorKind: AXElement] = [:]

        if decision == .reject(.notEditable) {
            for kind in AncestorKind.allCases {
                guard let ancestor = element.element(kind.attribute) else { continue }
                ancestorElements[kind] = ancestor
                snapshot.ancestors.append(FieldAncestor(kind, basicSnapshot(of: ancestor, secureInputActive: secureInput)))
            }
            if !snapshot.ancestors.isEmpty {
                decision = FieldClassifier.classify(snapshot)
            }
        }

        switch decision {
        case .accept(.focusedElement):
            return Inspection(decision: decision, target: element, role: snapshot.role)
        case .accept(.ancestor(let kind)):
            let role = snapshot.ancestors.first { $0.kind == kind }?.snapshot.role
            return Inspection(decision: decision, target: ancestorElements[kind], role: role)
        case .reject:
            return Inspection(decision: decision, target: nil, role: snapshot.role)
        }
    }

    static func basicSnapshot(of element: AXElement, secureInputActive: Bool) -> FieldSnapshot {
        var snapshot = FieldSnapshot(secureInputActive: secureInputActive)
        let identityAttributes = [kAXRoleAttribute, kAXSubroleAttribute, kAXRoleDescriptionAttribute]
        if let identity = element.copyValues(identityAttributes) {
            snapshot.role = AXValueConversion.string(identity[0])
            snapshot.subrole = AXValueConversion.string(identity[1])
            snapshot.roleDescription = AXValueConversion.string(identity[2])
        }
        if snapshot.role == nil {
            let (role, error) = element.copyValue(kAXRoleAttribute)
            switch error {
            case .invalidUIElement:
                snapshot.readFailure = .gone
                return snapshot
            case .cannotComplete:
                snapshot.readFailure = .unresponsive
                return snapshot
            default:
                snapshot.role = AXValueConversion.string(role)
                snapshot.subrole = snapshot.subrole ?? element.string(kAXSubroleAttribute)
            }
        }
        if FieldClassifier.isSecure(role: snapshot.role, subrole: snapshot.subrole, roleDescription: snapshot.roleDescription) {
            return snapshot
        }

        snapshot.isEnabled = element.bool(kAXEnabledAttribute)
        snapshot.isValueSettable = element.isSettable(kAXValueAttribute)
        snapshot.isSelectedTextSettable = element.isSettable(kAXSelectedTextAttribute)

        let role = snapshot.role ?? ""
        if !FieldClassifier.textRoles.contains(role), snapshot.isValueSettable == true {
            snapshot.valueIsString = AXValueConversion.isString(element.copyValue(kAXValueAttribute).value)
        }
        if FieldClassifier.singleLineRoles.contains(role) {
            let labels = element.copyValues([
                kAXIdentifierAttribute, AXName.domIdentifier, kAXPlaceholderValueAttribute,
                kAXTitleAttribute, kAXDescriptionAttribute,
            ]) ?? []
            snapshot.hints = labels.compactMap { AXValueConversion.string($0)?.lowercased() }.filter { !$0.isEmpty }
        }
        return snapshot
    }
}
