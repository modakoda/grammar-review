import Foundation
import GrammarModels

struct LanguageSource: Sendable {
    let keyboardLanguages: @Sendable () async -> KeyboardLanguages

    func resolver(for settings: AppSettings) async -> LanguageResolver {
        let needsKeyboard = LanguageResolver.needsKeyboard(settings.languageMode)
        return LanguageResolver(
            mode: settings.languageMode,
            keyboard: needsKeyboard ? await keyboardLanguages() : KeyboardLanguages(),
            preferredLanguages: Locale.preferredLanguages
        )
    }
}
