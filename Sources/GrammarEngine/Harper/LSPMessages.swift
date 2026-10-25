import Foundation

struct LSPPosition: Codable, Equatable, Sendable {
    var line: Int
    var character: Int

    var json: JSONValue { .object([("line", .int(line)), ("character", .int(character))]) }
}

struct LSPRange: Codable, Equatable, Sendable {
    var start: LSPPosition
    var end: LSPPosition

    var json: JSONValue { .object([("start", start.json), ("end", end.json)]) }
}

enum LSPID: Hashable, Sendable, Decodable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    var json: JSONValue {
        switch self {
        case .int(let value): .int(value)
        case .string(let value): .string(value)
        }
    }
}

struct LSPIncoming: Decodable {
    struct ResponseError: Decodable {
        var message: String
    }

    var id: LSPID?
    var method: String?
    var error: ResponseError?
}

struct LSPNotification<Params: Decodable>: Decodable {
    var params: Params
}

struct LSPResponse<Result: Decodable>: Decodable {
    var result: Result?
}

struct LSPConfigurationParams: Decodable {
    struct Item: Decodable {}
    var items: [Item]
}

struct LSPPublishDiagnostics: Decodable, Sendable {
    var uri: String
    var diagnostics: [LSPDiagnostic]
}

struct LSPDiagnostic: Decodable, Equatable, Sendable {
    var range: LSPRange
    var message: String
    var code: String?

    private enum CodingKeys: String, CodingKey {
        case range, message, code
    }

    init(range: LSPRange, message: String, code: String?) {
        self.range = range
        self.message = message
        self.code = code
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        range = try c.decode(LSPRange.self, forKey: .range)
        message = try c.decode(String.self, forKey: .message)
        if let text = try? c.decodeIfPresent(String.self, forKey: .code) {
            code = text
        } else if let number = try? c.decodeIfPresent(Int.self, forKey: .code) {
            code = String(number)
        } else {
            code = nil
        }
    }

    var json: JSONValue {
        var pairs: [(String, JSONValue)] = [("range", range.json), ("message", .string(message))]
        if let code { pairs.append(("code", .string(code))) }
        return .object(pairs)
    }
}

struct LSPTextEdit: Decodable, Equatable, Sendable {
    var range: LSPRange
    var newText: String
}

struct LSPCodeAction: Decodable, Equatable, Sendable {
    static let ignoreCommand = "HarperIgnoreLint"

    var title: String
    var edits: [String: [LSPTextEdit]]
    var lintKind: String?
    var lintMessage: String?

    private enum CodingKeys: String, CodingKey {
        case title, edit, command, arguments
    }

    private struct WorkspaceEdit: Decodable {
        var changes: [String: [LSPTextEdit]]?
    }

    private struct LintArgument: Decodable {
        var lintKind: String?
        var message: String?

        private enum CodingKeys: String, CodingKey {
            case lintKind = "lint_kind"
            case message
        }

        init(from decoder: Decoder) throws {
            let c = try? decoder.container(keyedBy: CodingKeys.self)
            lintKind = try? c?.decodeIfPresent(String.self, forKey: .lintKind)
            message = try? c?.decodeIfPresent(String.self, forKey: .message)
        }
    }

    init(title: String, edits: [String: [LSPTextEdit]] = [:], lintKind: String? = nil, lintMessage: String? = nil) {
        self.title = title
        self.edits = edits
        self.lintKind = lintKind
        self.lintMessage = lintMessage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decode(String.self, forKey: .title)
        edits = (try? c.decodeIfPresent(WorkspaceEdit.self, forKey: .edit))?.changes ?? [:]
        if (try? c.decodeIfPresent(String.self, forKey: .command)) == Self.ignoreCommand,
           let arguments = try? c.decodeIfPresent([LintArgument].self, forKey: .arguments) {
            let lint = arguments.first { $0.lintKind != nil || $0.message != nil }
            lintKind = lint?.lintKind
            lintMessage = lint?.message
        }
    }

    var isIgnoreCommand: Bool { lintKind != nil || lintMessage != nil }

    static func actions(for diagnostic: LSPDiagnostic, in actions: [LSPCodeAction]) -> [LSPCodeAction] {
        var group: [LSPCodeAction] = []
        for action in actions {
            group.append(action)
            guard action.isIgnoreCommand else { continue }
            if action.lintMessage == diagnostic.message { return group }
            group = []
        }
        return actions
    }
}

enum LSPOutgoing {
    static func request(id: Int, method: String, params: JSONValue) -> JSONValue {
        .object([("jsonrpc", .string("2.0")), ("id", .int(id)), ("method", .string(method)), ("params", params)])
    }

    static func notification(method: String, params: JSONValue) -> JSONValue {
        .object([("jsonrpc", .string("2.0")), ("method", .string(method)), ("params", params)])
    }

    static func response(id: LSPID, result: JSONValue) -> JSONValue {
        .object([("jsonrpc", .string("2.0")), ("id", id.json), ("result", result)])
    }

    static func document(_ uri: String) -> JSONValue {
        .object([("uri", .string(uri))])
    }
}
