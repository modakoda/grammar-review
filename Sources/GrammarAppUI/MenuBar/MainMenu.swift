import AppKit

public enum MainMenu {
    public static func install(openSettings: @escaping () -> Void, updater: (any AppUpdater)? = nil) {
        let main = NSMenu()
        main.addItem(submenu(appMenu(openSettings: openSettings, updater: updater)))
        main.addItem(submenu(editMenu()))
        let window = windowMenu()
        main.addItem(submenu(window))
        NSApp.mainMenu = main
        NSApp.windowsMenu = window
    }

    private static func submenu(_ menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: menu.title, action: nil, keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func appMenu(openSettings: @escaping () -> Void, updater: (any AppUpdater)?) -> NSMenu {
        let menu = NSMenu(title: "Grammar Review")
        menu.addItem(withTitle: "About Grammar Review", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        if let updater {
            menu.addItem(closureItem("Check for Updates…", isEnabled: { updater.canCheckForUpdates }, action: { updater.checkForUpdates() }))
        }
        menu.addItem(.separator())
        menu.addItem(closureItem("Settings…", keyEquivalent: ",", action: openSettings))
        menu.addItem(.separator())
        menu.addItem(withTitle: "Hide Grammar Review", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = menu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Grammar Review", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private static func editMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")
        menu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = menu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(.separator())
        menu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        let plain = menu.addItem(withTitle: "Paste and Match Style", action: #selector(NSTextView.pasteAsPlainText(_:)), keyEquivalent: "v")
        plain.keyEquivalentModifierMask = [.command, .option, .shift]
        menu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        menu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        menu.addItem(.separator())

        let find = NSMenu(title: "Find")
        let findActions: [(String, String, NSEvent.ModifierFlags, NSFindPanelAction)] = [
            ("Find…", "f", .command, .showFindPanel),
            ("Find Next", "g", .command, .next),
            ("Find Previous", "g", [.command, .shift], .previous),
            ("Use Selection for Find", "e", .command, .setFindString),
        ]
        for (title, key, modifiers, action) in findActions {
            let item = find.addItem(withTitle: title, action: #selector(NSTextView.performFindPanelAction(_:)), keyEquivalent: key)
            item.keyEquivalentModifierMask = modifiers
            item.tag = Int(action.rawValue)
        }
        menu.addItem(submenu(find))
        return menu
    }

    private static func closureItem(
        _ title: String,
        keyEquivalent: String = "",
        isEnabled: @escaping () -> Bool = { true },
        action: @escaping () -> Void
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(ClosureTarget.run), keyEquivalent: keyEquivalent)
        let target = ClosureTarget(action, isEnabled: isEnabled)
        item.target = target
        item.representedObject = target
        return item
    }

    private static func windowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")
        menu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        return menu
    }
}

private final class ClosureTarget: NSObject, NSMenuItemValidation {
    private let action: () -> Void
    private let isEnabled: () -> Bool

    init(_ action: @escaping () -> Void, isEnabled: @escaping () -> Bool) {
        self.action = action
        self.isEnabled = isEnabled
    }

    @objc func run() {
        action()
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        isEnabled()
    }
}
