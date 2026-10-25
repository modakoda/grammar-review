import AppKit
import GrammarModels

enum StatusMenuModel {
    static let pauseShort: TimeInterval = 30 * 60
    static let pauseLong: TimeInterval = 60 * 60

    static func items(
        status: MenuBarStatus,
        settings: AppSettings,
        frontmostApp: FrontmostAppInfo?,
        updates: UpdateMenuState = .unavailable,
        keyboard: KeyboardLanguages = KeyboardLanguages(),
        preferredLanguages: [String] = [],
        now: Date,
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> [StatusMenuItem] {
        let line = statusLine(for: status, settings: settings, now: now, calendar: calendar, locale: locale)
        let language = languageItems(
            mode: settings.languageMode,
            keyboard: keyboard,
            preferredLanguages: preferredLanguages,
            locale: locale
        )
        return [StatusMenuItem(line, command: status == .needsPermission ? .showOnboarding : nil), .separator]
            + [
                StatusMenuItem("Enabled", command: .toggleEnabled, isOn: settings.isEnabled),
                pauseItem(settings: settings, now: now),
                StatusMenuItem("AI Suggestions", command: .toggleAI, isOn: settings.aiEnabled),
                StatusMenuItem("Language", submenu: language),
            ]
            + frontmostAppItems(frontmostApp, settings: settings)
            + [.separator] + hotkeyItems
            + [.separator] + appItems(updates: updates)
    }

    private static func pauseItem(settings: AppSettings, now: Date) -> StatusMenuItem {
        let paused = settings.pausedUntil.map { $0 > now } ?? false
        let canPause = settings.isEnabled
        let pauseItems = [
            StatusMenuItem("For 30 Minutes", command: canPause ? .pause(pauseShort) : nil),
            StatusMenuItem("For 1 Hour", command: canPause ? .pause(pauseLong) : nil),
            StatusMenuItem("Until Tomorrow", command: canPause ? .pauseUntilTomorrow : nil),
            .separator,
            StatusMenuItem("Resume", command: paused || !settings.isEnabled ? .resume : nil),
        ]
        return StatusMenuItem("Pause", isOn: paused, submenu: pauseItems)
    }

    private static func frontmostAppItems(_ app: FrontmostAppInfo?, settings: AppSettings) -> [StatusMenuItem] {
        guard let app else { return [] }
        let isDisabled = settings.disabledBundleIDs.contains(app.bundleID)
        let toggle = StatusMenuItem(
            isDisabled ? "Enable in \(app.name)" : "Disable in \(app.name)",
            command: .setAppDisabled(bundleID: app.bundleID, disabled: !isDisabled)
        )
        guard !isDisabled else { return [toggle] }
        let goals = settings.goals(forApp: app.bundleID)
        return [toggle, StatusMenuItem(
            "Writing Goals in \(app.name)",
            isOn: goals.isNone ? nil : true,
            submenu: goalsItems(bundleID: app.bundleID, goals: goals)
        )]
    }

    private static var hotkeyItems: [StatusMenuItem] {
        [
            hotkeyItem("Open Editor…", command: .openEditor, hotkey: .openEditor),
            hotkeyItem("Show Suggestions", command: .showSuggestions, hotkey: .showSuggestions),
            hotkeyItem("Rewrite Selection or Sentence", command: .rewriteSelection, hotkey: .rewriteSelection),
            hotkeyItem("Write with AI…", command: .writeWithAI, hotkey: .writeWithAI),
        ]
    }

    private static func hotkeyItem(_ title: String, command: StatusMenuCommand, hotkey: Hotkey) -> StatusMenuItem {
        StatusMenuItem(title, command: command, keyEquivalent: hotkey.keyEquivalent, modifiers: hotkey.modifierFlags)
    }

    private static func appItems(updates: UpdateMenuState) -> [StatusMenuItem] {
        var items = [StatusMenuItem("Settings…", command: .openSettings, keyEquivalent: ",", modifiers: .command)]
        switch updates {
        case .unavailable:
            break
        case .checking:
            items.append(StatusMenuItem("Check for Updates…"))
        case .ready:
            items.append(StatusMenuItem("Check for Updates…", command: .checkForUpdates))
        case let .updateAvailable(version):
            items.append(StatusMenuItem("Update to Version \(version)…", command: .checkForUpdates))
        }
        items.append(StatusMenuItem("Setup Guide…", command: .showOnboarding))
        items.append(.separator)
        items.append(StatusMenuItem("Quit Grammar Review", command: .quit, keyEquivalent: "q", modifiers: .command))
        return items
    }
}
