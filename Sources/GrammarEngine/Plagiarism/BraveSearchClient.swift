import Foundation
import GrammarModels

struct WebSearchResult: Sendable, Equatable {
    var url: URL
    var title: String
    var description: String
    var snippets: [String]
    var siteName: String
    var published: Date?
}

protocol WebSearching: Sendable {
    func search(_ query: String, apiKey: String, count: Int) async throws -> [WebSearchResult]
}

struct BraveSearchClient: WebSearching {
    static let defaultBaseURL = URL(string: "https://api.search.brave.com")!
    static let timeout: TimeInterval = 20

    var session: URLSession = .shared
    var baseURL: URL = Self.defaultBaseURL

    func search(_ query: String, apiKey: String, count: Int) async throws -> [WebSearchResult] {
        var components = URLComponents(url: baseURL.appending(path: "res/v1/web/search"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "result_filter", value: "web"),
            URLQueryItem(name: "extra_snippets", value: "true"),
            URLQueryItem(name: "text_decorations", value: "false"),
            URLQueryItem(name: "spellcheck", value: "false"),
            URLQueryItem(name: "safesearch", value: "off"),
        ]
        guard let url = components?.url else { throw PlagiarismError.failed("The search couldn't be built.") }
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(apiKey, forHTTPHeaderField: "X-Subscription-Token")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .cancelled: throw CancellationError()
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed: throw PlagiarismError.offline
            case .timedOut: throw PlagiarismError.failed("Brave Search didn't answer in time. Try again.")
            default: throw PlagiarismError.failed("Couldn't reach Brave Search: \(error.localizedDescription)")
            }
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw Self.error(status: status, body: data) }
        guard let decoded = try? JSONDecoder().decode(Response.self, from: data) else {
            throw PlagiarismError.failed("Brave Search sent an answer Grammar Review couldn't read.")
        }
        return (decoded.web?.results ?? []).compactMap(\.result)
    }

    static func error(status: Int, body: Data) -> PlagiarismError {
        let detail = try? JSONDecoder().decode(ErrorResponse.self, from: body).error
        let code = detail?.code?.uppercased() ?? ""
        switch status {
        case 401, 403:
            return .invalidAPIKey
        case 422 where code.contains("TOKEN") || code.contains("SUBSCRIPTION"):
            return .invalidAPIKey
        case 402:
            return .usageLimitReached
        case 429:
            return code.contains("USAGE") || code.contains("QUOTA") ? .usageLimitReached : .rateLimited
        case 500...599:
            return .failed("Brave Search is having problems (HTTP \(status)). Try again later.")
        default:
            let reason = detail?.detail?.trimmedWhitespace ?? ""
            return .failed(reason.isEmpty ? "Brave Search returned an error (HTTP \(status))." : "Brave Search: \(reason)")
        }
    }

    private struct Response: Decodable {
        struct Web: Decodable {
            var results: [Result]?
        }

        struct Result: Decodable {
            struct Profile: Decodable {
                var name: String?
            }

            struct MetaURL: Decodable {
                var hostname: String?
            }

            var title: String?
            var url: String?
            var description: String?
            var extraSnippets: [String]?
            var pageAge: String?
            var profile: Profile?
            var metaURL: MetaURL?

            private enum CodingKeys: String, CodingKey {
                case title, url, description, profile
                case extraSnippets = "extra_snippets"
                case pageAge = "page_age"
                case metaURL = "meta_url"
            }

            var result: WebSearchResult? {
                guard let url = url.flatMap(URL.init(string:)), let scheme = url.scheme, ["http", "https"].contains(scheme) else { return nil }
                let host = metaURL?.hostname ?? url.host() ?? ""
                let site = profile?.name?.trimmedWhitespace.nilIfEmpty ?? (host.hasPrefix("www.") ? String(host.dropFirst(4)) : host)
                return WebSearchResult(
                    url: url,
                    title: title?.trimmedWhitespace.nilIfEmpty ?? site,
                    description: description ?? "",
                    snippets: extraSnippets ?? [],
                    siteName: site,
                    published: pageAge.flatMap(BraveSearchClient.date(from:))
                )
            }
        }

        var web: Web?
    }

    private struct ErrorResponse: Decodable {
        struct Detail: Decodable {
            var code: String?
            var detail: String?
        }

        var error: Detail?
    }

    static func date(from pageAge: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: pageAge) { return date }
        iso.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        if let date = iso.date(from: String(pageAge.prefix(19))) { return date }
        iso.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return iso.date(from: String(pageAge.prefix(10)))
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
