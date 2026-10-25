import Foundation
import GrammarModels
import Testing
@testable import GrammarAppUI

@Suite struct LanguageOptionsTests {
    let english = Locale(identifier: "en")

    @Test func convertsDeduplicatesAndSortsByName() {
        let options = LanguageOptions.make(from: ["lt", "en_GB", "en", "en_GB", "de"], displayLocale: english)
        #expect(options.map(\.code) == ["en", "en-GB", "de", "lt"])
        #expect(options.map(\.name) == ["English", "English (United Kingdom)", "German", "Lithuanian"])
    }

    @Test func namesFollowTheDisplayLocale() {
        let options = LanguageOptions.make(from: ["de"], displayLocale: Locale(identifier: "de"))
        #expect(options.first?.name == "Deutsch")
    }

    @Test func bcp47() {
        #expect(LanguageOptions.bcp47("pt_BR") == "pt-BR")
        #expect(LanguageOptions.bcp47("lt") == "lt")
        #expect(LanguageOptions.languageCode(of: "en-GB") == "en")
        #expect(LanguageOptions.languageCode(of: "pt_PT") == "pt")
    }

    @Test func preferredDefault() {
        let options = LanguageOptions.make(from: ["en", "en_GB", "lt", "pt_BR", "pt_PT"], displayLocale: english)
        #expect(LanguageOptions.preferredDefault(in: options, preferredLanguages: ["lt-LT", "en-US"]) == "lt")
        #expect(LanguageOptions.preferredDefault(in: options, preferredLanguages: ["en-GB"]) == "en-GB")
        #expect(LanguageOptions.preferredDefault(in: options, preferredLanguages: ["en-US"]) == "en")
        #expect(LanguageOptions.preferredDefault(in: options, preferredLanguages: ["pt"])?.hasPrefix("pt-") == true)
        #expect(LanguageOptions.preferredDefault(in: options, preferredLanguages: ["ja-JP"]) == options.first?.code)
        #expect(LanguageOptions.preferredDefault(in: [], preferredLanguages: ["en"]) == nil)
    }

    @Test func includingAddsAMissingSelection() {
        let options = LanguageOptions.make(from: ["en"], displayLocale: english)
        #expect(LanguageOptions.including("en", in: options, displayLocale: english) == options)
        #expect(LanguageOptions.including(nil, in: options, displayLocale: english) == options)
        let extended = LanguageOptions.including("fr-CA", in: options, displayLocale: english)
        #expect(extended.map(\.code) == ["en", "fr-CA"])
        #expect(extended.last?.name == "French (Canada)")
    }
}
