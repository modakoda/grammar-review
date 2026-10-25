import Foundation

public enum StyleGuideFile {
    public enum Format: String, Sendable, CaseIterable {
        case json
        case csv
    }

    public enum ReadError: Error, Equatable, LocalizedError {
        case unreadable
        case noRules

        public var errorDescription: String? {
            switch self {
            case .unreadable: "The file isn't a style guide: use JSON or CSV with term, replacement and note columns."
            case .noRules: "The file has no rules."
            }
        }
    }

    public static func encode(_ rules: [StyleRule], as format: Format) -> Data {
        switch format {
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let portable = rules.map { PortableRule(term: $0.term, replacement: $0.replacement, note: $0.note, matchCase: $0.matchCase) }
            return (try? encoder.encode(portable)) ?? Data("[]".utf8)
        case .csv:
            var lines = ["term,replacement,note,match case"]
            for rule in rules {
                lines.append([rule.term, rule.replacement, rule.note, rule.matchCase ? "yes" : ""].map(csvField).joined(separator: ","))
            }
            return Data((lines.joined(separator: "\n") + "\n").utf8)
        }
    }

    public static func decode(_ data: Data) throws -> [StyleRule] {
        guard let text = String(data: data, encoding: .utf8) else { throw ReadError.unreadable }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let rules: [StyleRule]
        if trimmed.hasPrefix("[") || trimmed.hasPrefix("{") {
            let decoder = JSONDecoder()
            if let list = try? decoder.decode([StyleRule].self, from: Data(trimmed.utf8)) {
                rules = list
            } else if let wrapped = try? decoder.decode(Wrapped.self, from: Data(trimmed.utf8)) {
                rules = wrapped.rules
            } else {
                throw ReadError.unreadable
            }
        } else {
            rules = csvRules(trimmed)
        }
        let usable = rules.filter(\.isUsable)
        guard !usable.isEmpty else { throw ReadError.noRules }
        return usable
    }

    public static func merge(_ imported: [StyleRule], into existing: [StyleRule]) -> [StyleRule] {
        var result = existing
        for rule in imported {
            let key = rule.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if let index = result.firstIndex(where: { $0.term.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key }) {
                result[index] = StyleRule(id: result[index].id, term: rule.term, replacement: rule.replacement, note: rule.note, matchCase: rule.matchCase)
            } else {
                result.append(rule)
            }
        }
        return result
    }

    private struct Wrapped: Decodable {
        var rules: [StyleRule]
    }

    private struct PortableRule: Encodable {
        var term: String
        var replacement: String
        var note: String
        var matchCase: Bool
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func csvRules(_ text: String) -> [StyleRule] {
        var rows = csvRows(text)
        if let header = rows.first, header.first?.trimmingCharacters(in: .whitespaces).lowercased() == "term" {
            rows.removeFirst()
        }
        return rows.compactMap { row in
            guard let term = row.first?.trimmingCharacters(in: .whitespaces), !term.isEmpty else { return nil }
            let field = { (index: Int) in row.indices.contains(index) ? row[index].trimmingCharacters(in: .whitespaces) : "" }
            let matchCase = ["yes", "true", "1", "y", "x"].contains(field(3).lowercased())
            return StyleRule(term: term, replacement: field(1), note: field(2), matchCase: matchCase)
        }
    }

    static func csvRows(_ text: String) -> [[String]] {
        let separator: Character = text.split(whereSeparator: \.isNewline).first.map { line in
            line.count(where: { $0 == ";" }) > line.count(where: { $0 == "," }) ? ";" : ","
        } ?? ","
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = Array(text).makeIterator()
        var pending: Character?
        func next() -> Character? {
            if let character = pending {
                pending = nil
                return character
            }
            return iterator.next()
        }
        while let character = next() {
            if inQuotes {
                if character == "\"" {
                    if let following = next() {
                        if following == "\"" {
                            field.append("\"")
                        } else {
                            inQuotes = false
                            pending = following
                        }
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else if character == "\"", field.isEmpty {
                inQuotes = true
            } else if character == separator {
                row.append(field)
                field = ""
            } else if character.isNewline {
                row.append(field)
                field = ""
                if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                row = []
            } else {
                field.append(character)
            }
        }
        row.append(field)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        return rows
    }
}
