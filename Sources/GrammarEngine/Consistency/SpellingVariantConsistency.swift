import Foundation
import GrammarModels

enum SpellingVariantConsistency {
    typealias Word = ConsistencyChecker.Word

    static let britishToAmerican: [String: String] = {
        var pairs: [String: String] = [:]
        func add(_ british: String, _ american: String, suffixes: [String]) {
            for suffix in suffixes {
                pairs[british + suffix] = american + suffix
            }
        }
        let our = ["", "s", "ed", "ing", "ful", "fully", "less", "able", "ite", "ites"]
        for stem in ["colo", "favo", "flavo", "hono", "humo", "labo", "neighbo", "behavio", "rumo", "harbo", "vapo", "savo", "endeavo", "armo", "odo", "glamo"] {
            add(stem + "ur", stem + "r", suffixes: our)
        }
        let ise = ["e", "es", "ed", "ing", "ation", "ations", "er", "ers"]
        for stem in ["organi", "reali", "recogni", "apologi", "categori", "criticis", "emphasi", "summari", "speciali",
                     "prioriti", "minimi", "maximi", "optimi", "customi", "authori", "standardi", "utili", "finali",
                     "memori", "visuali", "characteri", "normali", "personali", "centrali", "moderni", "symboli",
                     "civili", "legali", "globali", "synchroni", "initiali", "capitali", "sympathi", "harmoni"] {
            add(stem + "s", stem + "z", suffixes: ise)
        }
        for stem in ["analy", "paraly", "cataly"] {
            add(stem + "s", stem + "z", suffixes: ["e", "es", "ed", "ing"])
        }
        let doubledL = ["ed", "ing", "er", "ers"]
        for stem in ["travel", "cancel", "model", "label", "fuel", "signal", "level", "total", "channel", "marshal", "tunnel", "counsel"] {
            add(stem + "l", stem, suffixes: doubledL)
        }
        for (british, american) in [("centre", "center"), ("theatre", "theater"), ("fibre", "fiber"), ("litre", "liter"),
                                    ("calibre", "caliber"), ("sombre", "somber")] {
            add(british, american, suffixes: ["", "s"])
        }
        for (british, american) in [("defence", "defense"), ("offence", "offense"), ("pretence", "pretense"),
                                    ("catalogue", "catalog"), ("analogue", "analog"), ("grey", "gray"),
                                    ("judgement", "judgment"), ("ageing", "aging"), ("aluminium", "aluminum"),
                                    ("jewellery", "jewelry"), ("manoeuvre", "maneuver"), ("plough", "plow"),
                                    ("sceptical", "skeptical"), ("enrolment", "enrollment"), ("fulfil", "fulfill"),
                                    ("instalment", "installment"), ("cosy", "cozy"), ("moustache", "mustache"),
                                    ("pyjamas", "pajamas"), ("mould", "mold"), ("smoulder", "smolder"),
                                    ("oestrogen", "estrogen"), ("paediatric", "pediatric"), ("anaemia", "anemia")] {
            pairs[british] = american
            if !british.hasSuffix("s"), !british.hasSuffix("y") { pairs[british + "s"] = american + "s" }
        }
        return pairs
    }()

    static let americanToBritish: [String: String] = Dictionary(
        britishToAmerican.map { ($0.value, $0.key) },
        uniquingKeysWith: { first, _ in first }
    )

    static func issues(in words: [Word], language: String?) -> [TextIssue] {
        var british: [(Word, String)] = []
        var american: [(Word, String)] = []
        for word in words {
            let lower = word.text.lowercased()
            if let us = britishToAmerican[lower] {
                british.append((word, us))
            } else if let uk = americanToBritish[lower] {
                american.append((word, uk))
            }
        }
        guard !british.isEmpty, !american.isEmpty else { return [] }

        let preferBritish: Bool
        if british.count != american.count {
            preferBritish = british.count > american.count
        } else if let region = language.flatMap(region(of:)) {
            preferBritish = region != "US"
        } else {
            return []
        }
        let (minority, variant) = preferBritish ? (american, "British") : (british, "American")
        return minority.map { word, replacement in
            ConsistencyChecker.issue(
                word,
                replacement: ConsistencyChecker.matchingCase(of: word.text, replacement),
                message: "The rest of the text uses \(variant) spelling. Use one variant throughout.",
                category: .spelling
            )
        }
    }

    static func isEnglish(_ language: String) -> Bool {
        language == "en" || language.hasPrefix("en-") || language.hasPrefix("en_")
    }

    private static func region(of language: String) -> String? {
        let parts = language.split(whereSeparator: { $0 == "-" || $0 == "_" })
        return parts.count > 1 ? parts[1].uppercased() : nil
    }
}
