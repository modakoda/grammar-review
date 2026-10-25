import Foundation
import GrammarModels
import Testing
@testable import GrammarEngine

@Suite struct BraveSearchClientTests {
    static let results = #"""
    {"type":"search","query":{"original":"\"x\"","more_results_available":false},"web":{"type":"search","results":[
      {"title":"Declaration of Independence: A Transcription","url":"https://www.archives.gov/founding-docs/declaration-transcript",
       "description":"We hold these truths to be self-evident, that all men are created equal…","page_age":"2023-05-17T00:00:00",
       "profile":{"name":"National Archives","url":"https://www.archives.gov","long_name":"archives.gov"},
       "meta_url":{"scheme":"https","netloc":"archives.gov","hostname":"www.archives.gov","path":"› founding-docs"},
       "extra_snippets":["The unanimous Declaration of the thirteen united States of America"]},
      {"title":"","url":"https://www.example.org/page","description":"No profile here."},
      {"title":"Not a web page","url":"ftp://example.org/file"}
    ]}}
    """#

    private func client(_ server: MockServer) -> BraveSearchClient {
        BraveSearchClient(session: server.session, baseURL: server.baseURL)
    }

    @Test func sendsTheQueryWithTheKeyAndReadsTheResults() async throws {
        let server = MockServer { _, _ in .json(200, Self.results) }
        let results = try await client(server).search("\"We hold these truths\"", apiKey: "BSA-test", count: 10)

        let request = try #require(server.requests.first)
        #expect(request.path == "/res/v1/web/search")
        #expect(request.header("X-Subscription-Token") == "BSA-test")
        #expect(request.header("Accept") == "application/json")
        let items = URLComponents(url: request.request.url!, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let query = Dictionary(items.map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        #expect(query["q"] == "\"We hold these truths\"")
        #expect(query["count"] == "10")
        #expect(query["extra_snippets"] == "true")
        #expect(query["result_filter"] == "web")

        #expect(results.count == 2)
        #expect(results[0].siteName == "National Archives")
        #expect(results[0].snippets == ["The unanimous Declaration of the thirteen united States of America"])
        let published = try #require(results[0].published)
        #expect(Calendar(identifier: .gregorian).dateComponents(in: .gmt, from: published).year == 2023)
        #expect(results[1].siteName == "example.org")
        #expect(results[1].title == "example.org")
        #expect(results[1].published == nil)
    }

    @Test func errorsSayWhatWentWrong() async {
        func failure(_ status: Int, _ body: String = "{}") async -> PlagiarismError? {
            let server = MockServer { _, _ in .json(status, body) }
            do {
                _ = try await client(server).search("q", apiKey: "k", count: 1)
                return nil
            } catch {
                return error as? PlagiarismError
            }
        }
        #expect(await failure(401) == .invalidAPIKey)
        #expect(await failure(422, #"{"type":"ErrorResponse","error":{"code":"SUBSCRIPTION_TOKEN_INVALID","detail":"The provided subscription token is invalid."}}"#) == .invalidAPIKey)
        #expect(await failure(422, #"{"error":{"code":"VALIDATION","detail":"Unable to validate request parameter(s)"}}"#)
            == .failed("Brave Search: Unable to validate request parameter(s)"))
        #expect(await failure(429, #"{"error":{"code":"RATE_LIMITED","detail":"Request rate limit exceeded for plan."}}"#) == .rateLimited)
        #expect(await failure(429, #"{"error":{"code":"USAGE_LIMIT_EXCEEDED"}}"#) == .usageLimitReached)
        #expect(await failure(503) == .failed("Brave Search is having problems (HTTP 503). Try again later."))
    }

    @Test func beingOfflineIsItsOwnError() async {
        let server = MockServer { _, _ in .failure(.notConnectedToInternet) }
        await #expect(throws: PlagiarismError.offline) {
            try await client(server).search("q", apiKey: "k", count: 1)
        }
    }

    @Test func pageAgesInSeveralFormsAreRead() {
        #expect(BraveSearchClient.date(from: "2023-05-17T00:00:00") != nil)
        #expect(BraveSearchClient.date(from: "2023-05-17T10:20:30Z") != nil)
        #expect(BraveSearchClient.date(from: "2023-05-17") != nil)
        #expect(BraveSearchClient.date(from: "May 17, 2023") == nil)
    }
}
