import Foundation

nonisolated struct LanguageOption: Identifiable, Hashable, Sendable {
    var code: String
    var name: String
    var id: String { code }
}

nonisolated enum LanguageOptions {
    static func bcp47(_ code: String) -> String {
        code.replacingOccurrences(of: "_", with: "-")
    }

    static func make(from spellCheckerCodes: [String], displayLocale: Locale) -> [LanguageOption] {
        var seen = Set<String>()
        var options: [LanguageOption] = []
        for raw in spellCheckerCodes {
            let code = bcp47(raw)
            guard !code.isEmpty, seen.insert(code.lowercased()).inserted else { continue }
            options.append(LanguageOption(code: code, name: displayName(for: code, in: displayLocale)))
        }
        return options.sorted {
            $0.name.compare($1.name, options: [.caseInsensitive, .diacriticInsensitive], locale: displayLocale) == .orderedAscending
        }
    }

    static func displayName(for code: String, in locale: Locale) -> String {
        locale.localizedString(forIdentifier: code) ?? code
    }

    static func preferredDefault(in options: [LanguageOption], preferredLanguages: [String]) -> String? {
        let codes = options.map(\.code)
        for preferred in preferredLanguages {
            if let exact = codes.first(where: { $0.caseInsensitiveCompare(preferred) == .orderedSame }) {
                return exact
            }
            let language = languageCode(of: preferred)
            if let match = codes.first(where: { $0.caseInsensitiveCompare(language) == .orderedSame }) {
                return match
            }
            if let regional = codes.first(where: { languageCode(of: $0).caseInsensitiveCompare(language) == .orderedSame }) {
                return regional
            }
        }
        return codes.first
    }

    static func languageCode(of code: String) -> String {
        String(code.split(whereSeparator: { $0 == "-" || $0 == "_" }).first ?? Substring(code))
    }

    static func including(_ selected: String?, in options: [LanguageOption], displayLocale: Locale) -> [LanguageOption] {
        guard let selected, !options.contains(where: { $0.code == selected }) else { return options }
        return options + [LanguageOption(code: selected, name: displayName(for: selected, in: displayLocale))]
    }
}
