import AppKit
import GrammarModels
import Observation

public final class StatusBarController {
    private let settingsStore: SettingsStore
    private let actions: StatusBarActions
    private let updater: (any AppUpdater)?
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let bridge = MenuBridge()
    private var reportedStatus: MenuBarStatus = .active

    public init(settingsStore: SettingsStore, actions: StatusBarActions, updater: (any AppUpdater)? = nil) {
        self.settingsStore = settingsStore
        self.actions = actions
        self.updater = updater
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.behavior = []
        menu.autoenablesItems = false
        menu.delegate = bridge
        statusItem.menu = menu
        bridge.onNeedsUpdate = { [weak self] in self?.rebuildMenu() }
        bridge.onCommand = { [weak self] in self?.perform($0) }
        refreshButton()
        observeSettings()
    }

    public var status: MenuBarStatus { reportedStatus }

    public func setStatus(_ status: MenuBarStatus) {
        guard status != reportedStatus else { return }
        reportedStatus = status
        refreshButton()
    }

    public var displayedStatus: MenuBarStatus {
        StatusMenuModel.effectiveStatus(reported: reportedStatus, settings: settingsStore.settings, now: Date())
    }

    private func refreshButton() {
        guard let button = statusItem.button else { return }
        let status = displayedStatus
        let settings = settingsStore.settings
        let tooltip = StatusMenuModel.tooltip(for: status, settings: settings, now: Date())
        let image = NSImage(systemSymbolName: StatusMenuModel.symbolName(for: status), accessibilityDescription: tooltip)
            ?? NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: tooltip)
        image?.isTemplate = true
        button.image = image
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
    }

    private func observeSettings() {
        withObservationTracking {
            _ = settingsStore.settings
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.refreshButton()
                self?.observeSettings()
            }
        }
    }

    private func rebuildMenu() {
        settingsStore.expirePauseIfNeeded()
        let items = StatusMenuModel.items(
            status: displayedStatus,
            settings: settingsStore.settings,
            frontmostApp: Self.frontmostApp(),
            updates: UpdateMenuState(updater: updater),
            keyboard: KeyboardLanguages.read(),
            preferredLanguages: Locale.preferredLanguages,
            now: Date()
        )
        menu.removeAllItems()
        for item in items {
            menu.addItem(makeMenuItem(item))
        }
    }

    private func makeMenuItem(_ item: StatusMenuItem) -> NSMenuItem {
        if item.isSeparator { return .separator() }
        let menuItem = NSMenuItem(title: item.title, action: nil, keyEquivalent: item.keyEquivalent)
        if let command = item.command {
            menuItem.action = #selector(MenuBridge.performCommand(_:))
            menuItem.target = bridge
            menuItem.representedObject = CommandBox(command)
        }
        menuItem.keyEquivalentModifierMask = item.modifiers
        menuItem.isEnabled = item.isEnabled
        if let isOn = item.isOn {
            menuItem.state = isOn ? .on : .off
        }
        if let children = item.submenu {
            let submenu = NSMenu(title: item.title)
            submenu.autoenablesItems = false
            for child in children {
                submenu.addItem(makeMenuItem(child))
            }
            menuItem.submenu = submenu
        }
        return menuItem
    }

    private func perform(_ command: StatusMenuCommand) {
        switch command {
        case .showOnboarding: actions.showOnboarding()
        case .toggleEnabled: settingsStore.update { $0.isEnabled.toggle() }
        case let .pause(duration): settingsStore.pause(for: duration)
        case .pauseUntilTomorrow: settingsStore.pauseUntilTomorrow()
        case .resume: settingsStore.resume()
        case .toggleAI: settingsStore.update { $0.aiEnabled.toggle() }
        case let .setLanguageMode(mode): settingsStore.update { $0.languageMode = mode }
        case .openLanguageSettings: actions.openSettings(.languages)
        case let .setAppDisabled(bundleID, disabled): settingsStore.setApp(bundleID, disabled: disabled)
        case let .setAppGoals(bundleID, goals): settingsStore.setGoals(goals, forApp: bundleID)
        case .openGoalsSettings: actions.openSettings(.goals)
        case .showSuggestions: actions.showSuggestions()
        case .rewriteSelection: actions.rewriteSelection()
        case .writeWithAI: actions.writeWithAI()
        case .openEditor: actions.openEditor()
        case .openSettings: actions.openSettings(nil)
        case .checkForUpdates: updater?.checkForUpdates()
        case .quit: actions.quit()
        }
    }

    private static func frontmostApp() -> FrontmostAppInfo? {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
            let bundleID = app.bundleIdentifier,
            bundleID != Bundle.main.bundleIdentifier
        else { return nil }
        return FrontmostAppInfo(bundleID: bundleID, name: app.localizedName ?? bundleID)
    }
}

private final class MenuBridge: NSObject, NSMenuDelegate {
    var onNeedsUpdate: (() -> Void)?
    var onCommand: ((StatusMenuCommand) -> Void)?

    func menuNeedsUpdate(_ menu: NSMenu) {
        onNeedsUpdate?()
    }

    @objc func performCommand(_ sender: NSMenuItem) {
        guard let box = sender.representedObject as? CommandBox else { return }
        onCommand?(box.command)
    }
}

private final class CommandBox: NSObject {
    let command: StatusMenuCommand

    init(_ command: StatusMenuCommand) {
        self.command = command
    }
}
