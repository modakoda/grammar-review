import ApplicationServices
import Foundation

extension AXElement {
    func clippingAncestors() -> [AXElement] {
        let clippingRoles: Set<String> = [kAXScrollAreaRole, AXName.webAreaRole]
        let topLevelRoles: Set<String> = [kAXWindowRole, kAXSheetRole, kAXDrawerRole, "AXPopover"]
        var ancestors: [AXElement] = []
        var current = self.element(kAXParentAttribute)
        var reachedTop = false
        for _ in 0..<40 {
            guard let node = current, let values = node.copyValues([kAXRoleAttribute, kAXParentAttribute]) else { break }
            let role = AXValueConversion.string(values[0]) ?? ""
            if clippingRoles.contains(role) { ancestors.append(node) }
            if topLevelRoles.contains(role) {
                ancestors.append(node)
                reachedTop = true
                break
            }
            if role == kAXApplicationRole { break }
            current = AXValueConversion.element(values[1])
        }
        if !reachedTop, let window = self.element(kAXWindowAttribute) {
            ancestors.append(window)
        }
        return ancestors
    }
}
