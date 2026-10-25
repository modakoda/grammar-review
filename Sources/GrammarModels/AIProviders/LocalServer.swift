import Foundation

public struct LocalServerPreset: Sendable, Hashable, Identifiable {
    public var name: String
    public var url: String
    public var id: String { name }

    public static let lmStudio = LocalServerPreset(name: "LM Studio", url: "http://localhost:1234/v1")
    public static let all: [LocalServerPreset] = [
        .lmStudio,
        LocalServerPreset(name: "Ollama", url: "http://localhost:11434/v1"),
        LocalServerPreset(name: "llama.cpp server", url: "http://localhost:8080/v1"),
    ]
}

public enum LocalServerAddress {
    public static func baseURL(from raw: String) -> URL? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        guard var components = URLComponents(string: text),
              let scheme = components.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = components.host, !host.isEmpty
        else { return nil }
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        for suffix in ["/chat/completions", "/models"] where path.hasSuffix(suffix) {
            path.removeLast(suffix.count)
        }
        components.path = path.isEmpty ? "/v1" : path
        components.query = nil
        components.fragment = nil
        return components.url
    }
}
