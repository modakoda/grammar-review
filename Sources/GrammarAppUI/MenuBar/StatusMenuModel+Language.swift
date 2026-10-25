import Foundation
import GrammarModels

extension StatusMenuModel {
    static func languageItems(
        mode: LanguageMode,
        keyboard: KeyboardLanguages,
        preferredLanguages: [String],
        locale: Locale
    ) -> [StatusMenuItem] {
        func name(_ code: String) -> String {
            locale.localizedString(forIdentifier: code) ?? code
        }
        var items = [
            StatusMenuItem("Detect from Text", command: .setLanguageMode(.automatic), isOn: mode == .automatic),
            StatusMenuItem(
                keyboard.current.map { "Match Keyboard (\(name($0)))" } ?? "Match Keyboard",
                command: .setLanguageMode(.keyboard),
                isOn: mode == .keyboard
            ),
            .separator,
        ]
        var codes = keyboard.userLanguages(preferred: preferredLanguages)
        if case let .fixed(code) = mode, !code.trimmingCharacters(in: .whitespaces).isEmpty, !codes.contains(code) {
            codes.append(code)
        }
        let sorted = codes.sorted {
            name($0).compare(name($1), options: [.caseInsensitive, .diacriticInsensitive], locale: locale) == .orderedAscending
        }
        for code in sorted {
            items.append(StatusMenuItem(name(code), command: .setLanguageMode(.fixed(code)), isOn: mode == .fixed(code)))
        }
        items.append(.separator)
        items.append(StatusMenuItem("Other Languages…", command: .openLanguageSettings))
        return items
    }
}
