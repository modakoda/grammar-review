import Foundation
import GrammarModels
import NaturalLanguage
import os

struct LanguageResolver: Sendable {
    var mode: LanguageMode
    var keyboard: KeyboardLanguages
    var preferredLanguages: [String]

    init(mode: LanguageMode, keyboard: KeyboardLanguages = KeyboardLanguages(), preferredLanguages: [String] = []) {
        self.mode = mode
        self.keyboard = keyboard
        self.preferredLanguages = preferredLanguages
    }

    static func needsKeyboard(_ mode: LanguageMode) -> Bool {
        if case .fixed(let code) = mode { return code.trimmedWhitespace.isEmpty }
        return true
    }

    func language(of text: String) -> String? {
        imposedLanguage ?? detected(text) ?? keyboard.current
    }

    func language(ofParagraph text: String, overall: String?) -> String? {
        imposedLanguage ?? detected(text) ?? overall
    }

    private var imposedLanguage: String? {
        switch mode {
        case .automatic:
            return nil
        case .keyboard:
            return keyboard.current
        case .fixed(let code):
            let trimmed = code.trimmedWhitespace
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    private func detected(_ text: String) -> String? {
        LanguageDetector.detectAutomatically(text).map(corrected)
    }

    func corrected(_ detected: String) -> String {
        let own = keyboard.userLanguages(preferred: preferredLanguages)
        if own.contains(where: { KeyboardLanguages.isSameLanguage($0, detected) }) { return detected }
        if let current = keyboard.current, !LanguageDetector.canRecognize(current) { return current }
        return own.first { !LanguageDetector.canRecognize($0) } ?? detected
    }
}
