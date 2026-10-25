import Foundation
import GrammarModels
import NaturalLanguage
import os

enum LanguageDetector {
    static let minimumLetters = 20
    static let minimumConfidence = 0.5
    static let sampleLength = 4000

    private static let recognizable = OSAllocatedUnfairLock<[String: Bool]>(initialState: [:])

    static func canRecognize(_ code: String) -> Bool {
        if let known = recognizable.withLock({ $0[code] }) { return known }
        let known = [code, KeyboardLanguages.withoutRegion(code), KeyboardLanguages.baseLanguage(code)].contains { candidate in
            let recognizer = NLLanguageRecognizer()
            recognizer.languageConstraints = [NLLanguage(candidate)]
            recognizer.processString("a")
            return !recognizer.languageHypotheses(withMaximum: 1).isEmpty
        }
        recognizable.withLock { $0[code] = known }
        return known
    }

    static func detectAutomatically(_ text: String) -> String? {
        let sample = text.utf16.count > sampleLength ? String(text.prefix(sampleLength)) : text
        guard hasEnoughLetters(sample) else { return nil }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).max(by: { $0.value < $1.value }),
              language != .undetermined, confidence >= minimumConfidence else {
            return nil
        }
        return language.rawValue
    }

    static func hasEnoughLetters(_ text: String) -> Bool {
        var count = 0
        for character in text where character.isLetter {
            count += 1
            if count >= minimumLetters { return true }
        }
        return false
    }

    static func englishName(for code: String) -> String? {
        Locale(identifier: "en_US").localizedString(forIdentifier: code)
    }
}

enum SpellLanguage: Equatable, Sendable {
    case systemDefault
    case specific(String)
    case unsupported

    static func resolve(_ language: String?, available: [String], current: String?) -> SpellLanguage {
        guard let language, !language.isEmpty else { return .systemDefault }
        let wanted = normalize(language)
        let base = baseCode(wanted)
        let normalizedAvailable = available.map { (identifier: $0, normalized: normalize($0)) }
        func find(_ code: String) -> String? {
            normalizedAvailable.first { $0.normalized == code }?.identifier
        }
        let currentVariant = current.flatMap { current -> String? in
            baseCode(normalize(current)) == base ? find(normalize(current)) : nil
        }

        if wanted == base {
            if let currentVariant { return .specific(currentVariant) }
            if let plain = find(base) { return .specific(plain) }
        } else {
            if let exact = find(wanted) { return .specific(exact) }
            if let plain = find(base) { return .specific(plain) }
            if let currentVariant { return .specific(currentVariant) }
        }
        if let variant = normalizedAvailable.first(where: { baseCode($0.normalized) == base }) {
            return .specific(variant.identifier)
        }
        return .unsupported
    }

    private static func normalize(_ code: String) -> String {
        code.replacingOccurrences(of: "-", with: "_").lowercased()
    }

    private static func baseCode(_ normalized: String) -> String {
        String(normalized.prefix { $0 != "_" })
    }
}
