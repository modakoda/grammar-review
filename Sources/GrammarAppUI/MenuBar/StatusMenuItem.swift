import AppKit
import GrammarModels

enum StatusMenuCommand: Equatable {
    case showOnboarding
    case toggleEnabled
    case pause(TimeInterval)
    case pauseUntilTomorrow
    case resume
    case toggleAI
    case setLanguageMode(LanguageMode)
    case openLanguageSettings
    case setAppDisabled(bundleID: String, disabled: Bool)
    case setAppGoals(bundleID: String, goals: WritingGoals)
    case openGoalsSettings
    case showSuggestions
    case rewriteSelection
    case writeWithAI
    case openEditor
    case openSettings
    case checkForUpdates
    case quit
}

struct StatusMenuItem: Equatable {
    var title: String
    var command: StatusMenuCommand?
    var isOn: Bool?
    var keyEquivalent: String
    var modifiers: NSEvent.ModifierFlags
    var submenu: [StatusMenuItem]?
    var isSeparator: Bool

    init(
        _ title: String,
        command: StatusMenuCommand? = nil,
        isOn: Bool? = nil,
        keyEquivalent: String = "",
        modifiers: NSEvent.ModifierFlags = [],
        submenu: [StatusMenuItem]? = nil
    ) {
        self.title = title
        self.command = command
        self.isOn = isOn
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
        self.submenu = submenu
        isSeparator = false
    }

    static let separator: StatusMenuItem = {
        var item = StatusMenuItem("")
        item.isSeparator = true
        return item
    }()

    var isEnabled: Bool { command != nil || submenu != nil }
}

struct FrontmostAppInfo: Equatable {
    var bundleID: String
    var name: String
}
