import AppKit
import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct LanguageTests {
    static let english = "This is a perfectly ordinary English sentence about the weather."
    static let french = "Je voudrais un café avec du lait, s'il vous plaît, et un croissant."
    static let lithuanian = "Sveiki, norėčiau paklausti apie užsakymą ir pristatymą rytoj."
    static let german = "Ich möchte morgen früh mit dem Zug nach Berlin fahren, wenn es geht."

    static func lithuanianUser(typingOn current: String?) -> KeyboardLanguages {
        KeyboardLanguages(current: current, enabled: ["en", "lt"])
    }

    private func language(
        _ text: String,
        _ mode: LanguageMode = .automatic,
        keyboard: KeyboardLanguages = KeyboardLanguages(),
        preferred: [String] = []
    ) -> String? {
        LanguageResolver(mode: mode, keyboard: keyboard, preferredLanguages: preferred).language(of: text)
    }

    @Test func detectsLanguagesOfLongEnoughText() {
        #expect(language(Self.english) == "en")
        #expect(language(Self.french) == "fr")
    }

    @Test func shortTextIsUndeterminedWithoutAKeyboard() {
        #expect(language("Ths is a tset") == nil)
        #expect(language("") == nil)
    }

    @Test func shortTextTakesTheKeyboardsLanguage() {
        #expect(language("Ačiū labai", keyboard: Self.lithuanianUser(typingOn: "lt")) == "lt")
        #expect(language("Thanks a lot", keyboard: Self.lithuanianUser(typingOn: "en")) == "en")
    }

    @Test func fixedLanguageWins() {
        #expect(language(Self.english, .fixed("lt"), keyboard: Self.lithuanianUser(typingOn: "en")) == "lt")
        #expect(language("Hi", .fixed("de-DE")) == "de-DE")
        #expect(language("Hi", .fixed(" ")) == nil)
    }

    @Test func detectionCantRecognizeEveryLanguage() {
        #expect(!LanguageDetector.canRecognize("lt"))
        #expect(!LanguageDetector.canRecognize("lv"))
        #expect(LanguageDetector.canRecognize("en"))
        #expect(LanguageDetector.canRecognize("en-GB"))
        #expect(LanguageDetector.canRecognize("zh-Hans"))
        #expect(LanguageDetector.canRecognize("ru"))
        #expect(LanguageDetector.detectAutomatically(Self.lithuanian) != "lt")
    }

    @Test func languagesDetectionMisreadsFollowTheUsersLanguages() {
        #expect(language(Self.lithuanian, keyboard: Self.lithuanianUser(typingOn: "lt")) == "lt")
        #expect(language(Self.lithuanian, keyboard: Self.lithuanianUser(typingOn: "en")) == "lt")
        #expect(language(Self.lithuanian, keyboard: KeyboardLanguages(current: "en", enabled: ["en"]), preferred: ["en-LT", "lt-LT"]) == "lt")
        #expect(language(Self.english, keyboard: Self.lithuanianUser(typingOn: "lt")) == "en")
        #expect(language(Self.german, keyboard: KeyboardLanguages(current: "en", enabled: ["en"]), preferred: ["en-GB"]) == "de")
        #expect(language(Self.lithuanian, keyboard: KeyboardLanguages(current: "en", enabled: ["en"])) == LanguageDetector.detectAutomatically(Self.lithuanian))
    }

    @Test func keyboardModeFollowsTheLayout() {
        #expect(language(Self.english, .keyboard, keyboard: Self.lithuanianUser(typingOn: "lt")) == "lt")
        #expect(language(Self.lithuanian, .keyboard, keyboard: Self.lithuanianUser(typingOn: "en")) == "en")
        #expect(language(Self.french, .keyboard) == "fr")
        #expect(language("Hi", .keyboard) == nil)
    }

    @Test func paragraphsGetTheirOwnLanguageUnlessSettingsImposeOne() {
        let automatic = LanguageResolver(mode: .automatic, keyboard: Self.lithuanianUser(typingOn: "lt"))
        #expect(automatic.language(ofParagraph: Self.english, overall: "lt") == "en")
        #expect(automatic.language(ofParagraph: "Gerai", overall: "en") == "en")
        let keyboard = LanguageResolver(mode: .keyboard, keyboard: Self.lithuanianUser(typingOn: "lt"))
        #expect(keyboard.language(ofParagraph: Self.english, overall: "lt") == "lt")
        let fixed = LanguageResolver(mode: .fixed("de"))
        #expect(fixed.language(ofParagraph: Self.english, overall: "de") == "de")
    }

    @Test func onlyAFixedLanguageSkipsTheKeyboard() {
        #expect(LanguageResolver.needsKeyboard(.automatic))
        #expect(LanguageResolver.needsKeyboard(.keyboard))
        #expect(!LanguageResolver.needsKeyboard(.fixed("lt")))
        #expect(LanguageResolver.needsKeyboard(.fixed("")))
    }

    @Test func languageModeSurvivesSaving() throws {
        for mode: LanguageMode in [.automatic, .keyboard, .fixed("lt")] {
            var settings = AppSettings()
            settings.languageMode = mode
            let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
            #expect(decoded.languageMode == mode)
        }
    }

    @Test func usersLanguagesComeFromLayoutsThenPreferences() {
        let keyboard = KeyboardLanguages(current: "lt", enabled: ["en", "lt", "zh-Hans"])
        #expect(keyboard.userLanguages(preferred: ["en-LT", "lt-LT", "pt-BR", "zh-Hant-TW"]) == ["lt", "en", "zh-Hans", "pt"])
        #expect(KeyboardLanguages().userLanguages(preferred: []).isEmpty)
        #expect(KeyboardLanguages.withoutRegion("zh-Hans-CN") == "zh-Hans")
        #expect(KeyboardLanguages.withoutRegion("pt_BR") == "pt")
        #expect(KeyboardLanguages.isSameLanguage("en-GB", "en"))
        #expect(!KeyboardLanguages.isSameLanguage("lt", "lv"))
    }

    @Test func spellLanguageResolution() {
        let available = ["en", "en_GB", "en_AU", "fr", "pt_BR", "pt_PT", "de"]
        #expect(SpellLanguage.resolve(nil, available: available, current: "en") == .systemDefault)
        #expect(SpellLanguage.resolve("en", available: available, current: "en_GB") == .specific("en_GB"))
        #expect(SpellLanguage.resolve("en", available: available, current: "Multilingual") == .specific("en"))
        #expect(SpellLanguage.resolve("en-AU", available: available, current: "en_GB") == .specific("en_AU"))
        #expect(SpellLanguage.resolve("en-US", available: available, current: "en_GB") == .specific("en"))
        #expect(SpellLanguage.resolve("pt", available: available, current: nil) == .specific("pt_BR"))
        #expect(SpellLanguage.resolve("FR", available: available, current: nil) == .specific("fr"))
        #expect(SpellLanguage.resolve("lt", available: available, current: "en") == .unsupported)
    }

    @Test func englishLanguageNamesForPrompts() {
        #expect(LanguageDetector.englishName(for: "lt") == "Lithuanian")
        #expect(LanguageDetector.englishName(for: "en") == "English")
    }
}
