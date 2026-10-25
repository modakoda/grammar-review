import Foundation

public struct StyleRule: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var term: String
    public var replacement: String
    public var note: String
    public var matchCase: Bool

    public init(id: UUID = UUID(), term: String, replacement: String = "", note: String = "", matchCase: Bool = false) {
        self.id = id
        self.term = term
        self.replacement = replacement
        self.note = note
        self.matchCase = matchCase
    }

    public var isUsable: Bool {
        !term.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private enum CodingKeys: String, CodingKey {
        case id, term, replacement, note, matchCase
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        term = try c.decode(String.self, forKey: .term)
        replacement = (try? c.decodeIfPresent(String.self, forKey: .replacement)) ?? ""
        note = (try? c.decodeIfPresent(String.self, forKey: .note)) ?? ""
        matchCase = (try? c.decodeIfPresent(Bool.self, forKey: .matchCase)) ?? false
    }
}
