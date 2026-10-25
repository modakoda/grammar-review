import ApplicationServices
import Foundation

nonisolated enum WebContentProber {
    static func probe(app: AXElement, nodeBudget: Int = 250, maxDepth: Int = 12) -> WebContentProbe {
        guard let window = app.element(kAXFocusedWindowAttribute) ?? app.elements(kAXWindowsAttribute)?.first else {
            return .unknown
        }
        var queue: [(element: AXElement, depth: Int)] = [(window, 0)]
        var next = 0
        var truncated = false
        while next < queue.count {
            guard next < nodeBudget else { return .unknown }
            let (element, depth) = queue[next]
            next += 1
            guard let values = element.copyValues([kAXRoleAttribute, kAXChildrenAttribute]) else {
                truncated = true
                continue
            }
            let children = AXValueConversion.elements(values[1]) ?? []
            if AXValueConversion.string(values[0]) == AXName.webAreaRole {
                return children.isEmpty ? .empty : .exposed
            }
            if depth < maxDepth {
                queue.append(contentsOf: children.map { ($0, depth + 1) })
            } else if !children.isEmpty {
                truncated = true
            }
        }
        return truncated ? .unknown : .empty
    }
}
