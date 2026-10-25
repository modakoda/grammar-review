import Foundation
import GrammarModels

public struct StatusBarActions {
    public var openSettings: (SettingsTab?) -> Void
    public var showOnboarding: () -> Void
    public var rewriteSelection: () -> Void
    public var writeWithAI: () -> Void
    public var showSuggestions: () -> Void
    public var openEditor: () -> Void
    public var quit: () -> Void

    public init(
        openSettings: @escaping (SettingsTab?) -> Void,
        showOnboarding: @escaping () -> Void,
        rewriteSelection: @escaping () -> Void,
        writeWithAI: @escaping () -> Void,
        showSuggestions: @escaping () -> Void,
        openEditor: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.openSettings = openSettings
        self.showOnboarding = showOnboarding
        self.rewriteSelection = rewriteSelection
        self.writeWithAI = writeWithAI
        self.showSuggestions = showSuggestions
        self.openEditor = openEditor
        self.quit = quit
    }
}
