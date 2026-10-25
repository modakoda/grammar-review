using GrammarReview.Core.Checking;
using GrammarReview.Core.Engine;
using GrammarReview.Core.Harper;
using GrammarReview.Core.Issues;
using GrammarReview.Core.Settings;
using GrammarReview.Core.Text;

namespace GrammarReview.Core.Tests;

public class EngineTests
{
    private sealed class FakeSpelling : ISpellChecker
    {
        public List<string> Learned { get; } = [];

        public IReadOnlyList<TextIssue> Misspellings(string text, string? language, AppSettings settings)
        {
            var index = text.IndexOf("teh", StringComparison.Ordinal);
            return index < 0 ? [] : [new TextIssue(new TextSpan(index, 3), "teh", ["the", "tech"], "Possible spelling mistake.", IssueCategory.Spelling, IssueSource.Local)];
        }

        public void Learn(string word) => Learned.Add(word);
    }

    private sealed class FakeProofreader(Func<string, IReadOnlyList<AIEdit>>? answer = null, AIException? failure = null) : IProofreader
    {
        public List<(string Paragraph, string? Language)> Calls { get; } = [];

        public Task<IReadOnlyList<AIEdit>> ProofreadAsync(string paragraph, string? language, string model, string apiKey, CancellationToken cancellation)
        {
            lock (Calls) Calls.Add((paragraph, language));
            if (failure is not null) throw failure;
            return Task.FromResult(answer?.Invoke(paragraph) ?? Edits(paragraph));
        }

        private static IReadOnlyList<AIEdit> Edits(string paragraph)
        {
            var edits = new List<AIEdit>();
            if (paragraph.Contains("has", StringComparison.Ordinal)) edits.Add(new AIEdit("has", "have", "I ", "Use have.", IssueCategory.Grammar));
            if (paragraph.Contains("teh", StringComparison.Ordinal)) edits.Add(new AIEdit("teh", "the", "has ", "Spelling.", IssueCategory.Spelling));
            return edits;
        }
    }

    private static readonly AppSettings Settings = new() { AIDelaySeconds = 0, Language = "en" };

    private static async Task<List<CheckResult>> Collect(GrammarEngine engine, CheckRequest request)
    {
        var results = new List<CheckResult>();
        await foreach (var result in engine.CheckAsync(request, TestContext.Current.CancellationToken)) results.Add(result);
        return results;
    }

    [Fact]
    public async Task LocalResultsComeFirstThenTheMergedFinalOnes()
    {
        var ai = new FakeProofreader();
        var engine = new GrammarEngine(new FakeSpelling(), ai, () => "sk-test");
        var results = await Collect(engine, new CheckRequest("I has teh cat.", Settings));

        Assert.Equal([AIState.Pending, AIState.Completed], results.Select(r => r.Status.State));
        Assert.Equal(["teh"], results[0].Issues.Select(i => i.OriginalText));
        Assert.Equal(["has", "teh"], results[1].Issues.Select(i => i.OriginalText));
        Assert.Equal(["the", "tech"], results[1].Issues[1].Replacements);
        Assert.Equal([("I has teh cat.", (string?)"en")], ai.Calls);
    }

    [Fact]
    public async Task OnlyChangedParagraphsAreSentAgain()
    {
        var ai = new FakeProofreader();
        var engine = new GrammarEngine(new FakeSpelling(), ai, () => "sk-test");
        await Collect(engine, new CheckRequest("First line is fine.\n\nI has a cat.", Settings));
        var results = await Collect(engine, new CheckRequest("First line is fine.\n\nI has a dog.", Settings));
        Assert.Equal(["First line is fine.", "I has a cat.", "I has a dog."], ai.Calls.Select(c => c.Paragraph).Order());
        Assert.Equal(23, results[^1].Issues.Single().Range.Start);
    }

    [Fact]
    public async Task WithoutAKeyOrWithAIOffOnlyLocalIssuesArrive()
    {
        var ai = new FakeProofreader();
        var noKey = await Collect(new GrammarEngine(new FakeSpelling(), ai, () => " "), new CheckRequest("I has teh cat.", Settings));
        Assert.Equal(AIState.MissingApiKey, Assert.Single(noKey).Status.State);
        var off = await Collect(new GrammarEngine(new FakeSpelling(), ai, () => "k"), new CheckRequest("I has teh cat.", Settings with { AIEnabled = false }));
        Assert.Equal(AIState.Disabled, Assert.Single(off).Status.State);
        var tooLong = await Collect(new GrammarEngine(new FakeSpelling(), ai, () => "k"), new CheckRequest("I has teh cat.", Settings with { MaxAICharacters = 5 }));
        Assert.Equal(AIState.TextTooLong, Assert.Single(tooLong).Status.State);
        Assert.Empty(ai.Calls);
    }

    [Fact]
    public async Task AIFailuresKeepTheLocalIssuesAndSayWhy()
    {
        var engine = new GrammarEngine(new FakeSpelling(), new FakeProofreader(failure: new AIException(AIErrorKind.InvalidApiKey)), () => "k");
        var results = await Collect(engine, new CheckRequest("I has teh cat.", Settings));
        Assert.Equal(new AIStatus(AIState.Failed, "Invalid API key"), results[^1].Status);
        Assert.Equal(["teh"], results[^1].Issues.Select(i => i.OriginalText));
    }

    [Fact]
    public async Task HarperJoinsTheLocalPassForEnglish()
    {
        var harper = new HarperChecker(
            new HarperTests.FakeLinter(text => [new HarperLint(new TextSpan(text.IndexOf("an ", StringComparison.Ordinal), 2), "AnA", "Miscellaneous", "Incorrect indefinite article.", ["a"])]),
            new HarperLocator(new Dictionary<string, string?>(), "/Users/me", _ => true, windows: false));
        var engine = new GrammarEngine(new FakeSpelling(), new FakeProofreader(_ => []), () => null, harper);
        var keyboardEnglish = await Collect(engine, new CheckRequest("This is an teh test.", Settings with { Language = null }, KeyboardLanguage: "en-GB"));
        Assert.Equal(["an", "teh"], keyboardEnglish[0].Issues.Select(i => i.OriginalText));
        var lithuanian = await Collect(engine, new CheckRequest("This is an teh test.", Settings with { Language = "lt" }));
        Assert.Equal(["teh"], lithuanian[0].Issues.Select(i => i.OriginalText));
    }

    [Fact]
    public void TheCacheForgetsTheLeastRecentlyUsed()
    {
        var cache = new EditCache(capacity: 2);
        EditCache.Key Key(string text) => new("m", "en", text);
        cache.Set(Key("a"), []);
        cache.Set(Key("b"), []);
        Assert.NotNull(cache.Get(Key("a")));
        cache.Set(Key("c"), []);
        Assert.Null(cache.Get(Key("b")));
        Assert.NotNull(cache.Get(Key("a")));
        Assert.NotNull(cache.Get(Key("c")));
    }
}

public class SettingsFileTests
{
    [Fact]
    public void SettingsRoundTripAndBadFilesGiveDefaults()
    {
        var path = Path.Combine(Path.GetTempPath(), $"grammar-review-{Guid.NewGuid():N}", "settings.json");
        var file = new SettingsFile(path);
        Assert.Equal(new AppSettings().Model, file.Load().Model);

        var settings = new AppSettings
        {
            AIEnabled = false,
            Model = "claude-sonnet-5-5",
            AIDelaySeconds = 2.5,
            Language = "lt-LT",
            HarperPath = @"C:\tools\harper-ls.exe",
            EnabledCategories = new HashSet<IssueCategory> { IssueCategory.Spelling, IssueCategory.Style },
            DisabledApps = new HashSet<string>(["Slack"], StringComparer.OrdinalIgnoreCase),
            PersonalDictionary = ["Kažinauskas"],
        };
        file.Save(settings);
        var loaded = file.Load();
        Assert.False(loaded.AIEnabled);
        Assert.Equal("claude-sonnet-5-5", loaded.Model);
        Assert.Equal(2.5, loaded.AIDelaySeconds);
        Assert.Equal("lt-LT", loaded.Language);
        Assert.Equal(@"C:\tools\harper-ls.exe", loaded.HarperPath);
        Assert.Equal([IssueCategory.Spelling, IssueCategory.Style], loaded.EnabledCategories.Order());
        Assert.True(loaded.DisabledApps.Contains("slack"));
        Assert.True(loaded.IsInPersonalDictionary("kažinauskas"));
        Assert.Contains("\"enabledCategories\": [\n    \"spelling\",", File.ReadAllText(path).ReplaceLineEndings("\n"), StringComparison.Ordinal);

        File.WriteAllText(path, "{ not json");
        Assert.True(file.Load().AIEnabled);
        Directory.Delete(Path.GetDirectoryName(path)!, recursive: true);
    }
}
