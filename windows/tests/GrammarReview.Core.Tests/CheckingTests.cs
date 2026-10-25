using System.Net;
using System.Text.Json.Nodes;
using GrammarReview.Core.Checking;
using GrammarReview.Core.Issues;
using GrammarReview.Core.Settings;
using GrammarReview.Core.Text;

namespace GrammarReview.Core.Tests;

public class CheckingTests
{
    private static AIEdit Edit(string original, string replacement, string before = "", IssueCategory category = IssueCategory.Grammar) =>
        new(original, replacement, before, "Fix.", category);

    [Fact]
    public void TheQuotedContextPicksTheRightOccurrence()
    {
        const string paragraph = "He go home and they go home.";
        var located = EditLocator.Locate([Edit("go", "goes", "He "), Edit("go", "went", "they ")], paragraph);
        Assert.Equal([3, 20], located.Select(l => l.Range.Start));
        var issues = EditLocator.Issues(located, 10);
        Assert.Equal([13, 30], issues.Select(i => i.Range.Start));
        Assert.All(issues, issue => Assert.Equal(IssueSource.AI, issue.Source));
    }

    [Fact]
    public void EditsThatAreMissingOrChangeNothingAreDropped()
    {
        var located = EditLocator.Locate([Edit("nope", "yes"), Edit("cat", "cat"), Edit("", "x")], "The cat sat.");
        Assert.Empty(located);
    }

    [Fact]
    public void WholeWordsBeatPartsOfWords()
    {
        var located = EditLocator.Locate([Edit("cat", "dog")], "concatenate the cat");
        Assert.Equal(16, Assert.Single(located).Range.Start);
    }

    [Fact]
    public void EmojiShiftOffsetsByTwoUnits()
    {
        var located = EditLocator.Locate([Edit("teh", "the")], "😀 teh cat");
        Assert.Equal(3, Assert.Single(located).Range.Start);
    }

    [Fact]
    public void AIWinsOverlapsButSpellingGuessesJoinIt()
    {
        var settings = new AppSettings();
        TextIssue Make(int start, string text, IssueCategory category, IssueSource source, params string[] fixes) =>
            new(new TextSpan(start, text.Length), text, fixes, "m", category, source);
        var local = new[] { Make(6, "teh", IssueCategory.Spelling, IssueSource.Local, "the", "tech"), Make(14, "very", IssueCategory.Style, IssueSource.Local, "") };
        var ai = new[] { Make(6, "teh", IssueCategory.Spelling, IssueSource.AI, "the"), Make(10, "cat very", IssueCategory.Grammar, IssueSource.AI, "cat") };
        var merged = IssueMerger.Merge(local, ai, settings);
        Assert.Equal(["teh", "cat very"], merged.Select(i => i.OriginalText));
        Assert.Equal(["the", "tech"], merged[0].Replacements);
    }

    [Fact]
    public void DisabledCategoriesAndDictionaryWordsAreHidden()
    {
        var settings = new AppSettings { EnabledCategories = new HashSet<IssueCategory> { IssueCategory.Spelling }, PersonalDictionary = ["Kažinauskas"] };
        var local = new[]
        {
            new TextIssue(new TextSpan(0, 11), "kažinauskas", [], "m", IssueCategory.Spelling, IssueSource.Local),
            new TextIssue(new TextSpan(12, 3), "teh", ["the"], "m", IssueCategory.Spelling, IssueSource.Local),
            new TextIssue(new TextSpan(16, 2), "is", ["are"], "m", IssueCategory.Grammar, IssueSource.Local),
        };
        Assert.Equal(["teh"], IssueMerger.Merge(local, [], settings).Select(i => i.OriginalText));
    }

    [Fact]
    public void ParsesTheEditsEvenWithTextAround()
    {
        const string answer = """
            Here you go:
            {"edits":[{"context_before":"I ","original":"has","replacement":"have","explanation":" Use have. ","category":"word_choice"},{"original":"x"}]}
            """;
        var edits = CheckPrompt.ParseEdits(answer);
        var edit = Assert.Single(edits!);
        Assert.Equal(new AIEdit("has", "have", "I ", "Use have.", IssueCategory.WordChoice), edit);
        Assert.Null(CheckPrompt.ParseEdits("not json"));
        Assert.Empty(CheckPrompt.ParseEdits("""{"edits":[]}""")!);
    }

    [Fact]
    public void RefusalsAndCutOffAnswersAreErrors()
    {
        Assert.Equal(AIErrorKind.Refused, Assert.Throws<AIException>(() => CheckPrompt.Parse(new ClaudeResponse("", "refusal"))).Kind);
        Assert.Equal(AIErrorKind.Truncated, Assert.Throws<AIException>(() => CheckPrompt.Parse(new ClaudeResponse("{\"ed", "max_tokens"))).Kind);
    }

    [Fact]
    public void ThePromptNamesTheLanguageAndFencesTheText()
    {
        Assert.StartsWith("The text is written in English (United Kingdom) (en-GB).", CheckPrompt.UserMessage("Hi there.", "en-GB"));
        Assert.StartsWith("Work out which language", CheckPrompt.UserMessage("Hi.", null));
        Assert.EndsWith("<text_to_check>\nHi.\n</text_to_check>", CheckPrompt.UserMessage("Hi.", null));
        var categories = CheckPrompt.Schema()["properties"]!["edits"]!["items"]!["properties"]!["category"]!["enum"]!.AsArray();
        Assert.Equal(["spelling", "grammar", "punctuation", "wordChoice", "clarity", "style"], categories.Select(c => c!.GetValue<string>()));
    }
}

public class ClaudeClientTests
{
    private sealed class FakeHandler(Func<HttpRequestMessage, string, int, HttpResponseMessage> respond) : HttpMessageHandler
    {
        public List<(HttpRequestMessage Request, string Body)> Requests { get; } = [];

        protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            var body = request.Content is null ? "" : await request.Content.ReadAsStringAsync(cancellationToken);
            Requests.Add((request, body));
            return respond(request, body, Requests.Count);
        }
    }

    private static HttpResponseMessage Json(HttpStatusCode status, string json) => new(status) { Content = new StringContent(json) };

    private const string Answer = """
        {"id":"msg","type":"message","content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\"edits\":[]}"}],"stop_reason":"end_turn"}
        """;

    [Fact]
    public async Task SendsTheMessagesRequest()
    {
        var handler = new FakeHandler((_, _, _) => Json(HttpStatusCode.OK, Answer));
        var client = new ClaudeClient(new HttpClient(handler), retryDelay: TimeSpan.Zero);
        var response = await client.CreateMessageAsync(CheckPrompt.Request("I has a cat.", "en", "claude-haiku-5-5"), "sk-test", CancellationToken.None);

        Assert.Equal("""{"edits":[]}""", response.Text);
        var (request, body) = Assert.Single(handler.Requests);
        Assert.Equal("https://api.anthropic.com/v1/messages", request.RequestUri!.ToString());
        Assert.Equal("sk-test", request.Headers.GetValues("x-api-key").Single());
        Assert.Equal(ClaudeClient.ApiVersion, request.Headers.GetValues("anthropic-version").Single());
        var json = JsonNode.Parse(body)!;
        Assert.Equal("claude-haiku-5-5", json["model"]!.GetValue<string>());
        Assert.Equal("ephemeral", json["system"]![0]!["cache_control"]!["type"]!.GetValue<string>());
        Assert.Equal("json_schema", json["output_config"]!["format"]!["type"]!.GetValue<string>());
        Assert.Equal("low", json["output_config"]!["effort"]!.GetValue<string>());
        Assert.Contains("I has a cat.", json["messages"]![0]!["content"]!.GetValue<string>());
    }

    [Fact]
    public async Task ABusyServerIsRetriedOnce()
    {
        var handler = new FakeHandler((_, _, attempt) => attempt == 1 ? Json((HttpStatusCode)529, "{}") : Json(HttpStatusCode.OK, Answer));
        var client = new ClaudeClient(new HttpClient(handler), retryDelay: TimeSpan.Zero);
        await client.CreateMessageAsync(CheckPrompt.Request("x", null, "m"), "k", CancellationToken.None);
        Assert.Equal(2, handler.Requests.Count);

        var busy = new FakeHandler((_, _, _) => Json(HttpStatusCode.TooManyRequests, "{}"));
        var error = await Assert.ThrowsAsync<AIException>(() => new ClaudeClient(new HttpClient(busy), retryDelay: TimeSpan.Zero)
            .CreateMessageAsync(CheckPrompt.Request("x", null, "m"), "k", CancellationToken.None));
        Assert.Equal(AIErrorKind.Busy, error.Kind);
        Assert.Equal(2, busy.Requests.Count);
    }

    [Theory]
    [InlineData(401, "{}", AIErrorKind.InvalidApiKey)]
    [InlineData(429, """{"error":{"type":"rate_limit_error","message":"cap","details":{"error_code":"enforced_spend_limit_reached"}}}""", AIErrorKind.SpendCapReached)]
    [InlineData(400, """{"error":{"type":"invalid_request_error","message":"Bad thing"}}""", AIErrorKind.Http)]
    public async Task ErrorsAreSorted(int status, string body, AIErrorKind kind)
    {
        var handler = new FakeHandler((_, _, _) => Json((HttpStatusCode)status, body));
        var error = await Assert.ThrowsAsync<AIException>(() => new ClaudeClient(new HttpClient(handler), retryDelay: TimeSpan.Zero)
            .CreateMessageAsync(CheckPrompt.Request("x", null, "m"), "k", CancellationToken.None));
        Assert.Equal(kind, error.Kind);
        Assert.Single(handler.Requests);
        if (kind == AIErrorKind.Http) Assert.Equal("Claude error: Bad thing", error.UserMessage);
    }

    [Fact]
    public async Task KeysAreTestedByCountingTokens()
    {
        var handler = new FakeHandler((request, _, _) => request.RequestUri!.AbsolutePath == "/v1/messages/count_tokens"
            ? Json(HttpStatusCode.OK, """{"input_tokens":8}""")
            : Json(HttpStatusCode.NotFound, "{}"));
        var client = new ClaudeClient(new HttpClient(handler), retryDelay: TimeSpan.Zero);
        await client.ValidateKeyAsync("sk-test", "claude-haiku-5-5", CancellationToken.None);
        var body = JsonNode.Parse(handler.Requests.Single().Body)!;
        Assert.Equal("claude-haiku-5-5", body["model"]!.GetValue<string>());

        var rejected = new FakeHandler((_, _, _) => Json(HttpStatusCode.Unauthorized, "{}"));
        var error = await Assert.ThrowsAsync<AIException>(() =>
            new ClaudeClient(new HttpClient(rejected)).ValidateKeyAsync("bad", "claude-haiku-5-5", CancellationToken.None));
        Assert.Equal(AIErrorKind.InvalidApiKey, error.Kind);
    }

    [Fact]
    public void OnlyTheAnswerAfterTheLastFallbackCounts()
    {
        var response = ClaudeClient.Decode("""
            {"content":[{"type":"text","text":"old"},{"type":"fallback"},{"type":"text","text":"new"}],"stop_reason":"end_turn"}
            """);
        Assert.Equal("new", response.Text);
        Assert.Throws<AIException>(() => ClaudeClient.Decode("not json"));
    }
}
