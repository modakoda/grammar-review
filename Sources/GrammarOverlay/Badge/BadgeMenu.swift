import AppKit
import GrammarModels

enum BadgeMenu {
    nonisolated static let spacingSteps: [Double] = [4, 8, 12, 16, 24, 32, 40]

    static func make(kind: FieldKind, placement: BadgePlacement, spacing: Double, actions: OverlayActions) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(.sectionHeader(title: "Badge in \(kind.displayName)"))
        let groups: [[BadgePlacement]] = [
            [.automatic],
            BadgePlacement.allCases.filter(\.isInside),
            BadgePlacement.allCases.filter { !$0.isInside && $0 != .automatic },
        ]
        for (index, group) in groups.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            for option in group {
                let choice = item(option.displayName) { actions.setBadgePlacement(option, kind) }
                choice.state = option == placement ? .on : .off
                choice.toolTip = option.detail(for: kind)
                menu.addItem(choice)
            }
        }

        menu.addItem(.separator())
        let distance = NSMenuItem(title: "Distance from the Field", action: nil, keyEquivalent: "")
        distance.submenu = spacingMenu(current: spacing, actions: actions)
        distance.isEnabled = !placement.isInside
        menu.addItem(distance)

        menu.addItem(.separator())
        menu.addItem(item("Badge Settings…") { actions.openBadgeSettings() })
        return menu
    }

    nonisolated static func spacingOptions(current: Double) -> [Double] {
        Set(spacingSteps + [current]).sorted()
    }

    private static func spacingMenu(current: Double, actions: OverlayActions) -> NSMenu {
        let menu = NSMenu()
        for option in spacingOptions(current: current) {
            let choice = item("\(Int(option)) pt") { actions.setBadgeSpacing(option) }
            choice.state = option == current ? .on : .off
            menu.addItem(choice)
        }
        return menu
    }

    private static func item(_ title: String, action: @escaping () -> Void) -> NSMenuItem {
        let target = ClosureTarget(action)
        let item = NSMenuItem(title: title, action: #selector(ClosureTarget.run), keyEquivalent: "")
        item.target = target
        item.representedObject = target
        return item
    }
}

private final class ClosureTarget: NSObject {
    private let action: () -> Void

    init(_ action: @escaping () -> Void) {
        self.action = action
    }

    @objc func run() {
        action()
    }
}
