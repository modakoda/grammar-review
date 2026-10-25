using System.Text;
using System.Text.Json.Nodes;
using GrammarReview.Core.Harper;
using GrammarReview.Core.Issues;
using GrammarReview.Core.Settings;
using GrammarReview.Core.Text;

namespace GrammarReview.Core.Tests;

public class HarperTests
{
    private const string Uri = "untitled:grammar-review-1";

    private static LspRange Range(int line, int start, int end) => new(new LspPosition(line, start), new LspPosition(line, end));

    private static LspCodeAction Fix(LspRange range, string newText) =>
        new("Replace", new Dictionary<string, IReadOnlyList<LspTextEdit>> { [Uri] = [new LspTextEdit(range, newText)] });

    private static LspCodeAction Ignore(string kind, string message) => new("Ignore Harper error.", new Dictionary<string, IReadOnlyList<LspTextEdit>>(), kind, message);

    [Fact]
    public void FramesAreReassembledAcrossChunks()
    {
        var decoder = new LspFrameDecoder();
        var data = LspFrameDecoder.Frame("""{"id":1}""").Concat(LspFrameDecoder.Frame("""{"text":"ąčę 😀"}""")).ToArray();
        var messages = new List<string>();
        for (var i = 0; i < data.Length; i += 5)
        {
            messages.AddRange(decoder.Append(data.AsSpan(i, Math.Min(5, data.Length - i))).Select(Encoding.UTF8.GetString));
        }
        Assert.Equal(["""{"id":1}""", """{"text":"ąčę 😀"}"""], messages);
        Assert.Equal(2, LspFrameDecoder.ContentLength("content-type: x\r\nCONTENT-LENGTH:  2"));
        Assert.Null(LspFrameDecoder.ContentLength("X-Junk: 1"));
    }

    [Fact]
    public void PositionsAreUtf16OffsetsOnEachLine()
    {
        var lines = new LspLineIndex("a😀b\nsecond\r\nthird\rfourth");
        Assert.Equal(3, lines.Offset(new LspPosition(0, 3)));
        Assert.Equal(15, lines.Offset(new LspPosition(2, 2)));
        Assert.Equal(25, lines.Offset(new LspPosition(3, 6)));
        Assert.Equal(4, lines.Offset(new LspPosition(0, 99)));
        Assert.Null(lines.Offset(new LspPosition(4, 0)));
    }

    // Recorded from harper-ls 2.13.0.
    private const string CodeActions = """
        [{"command":{"arguments":["{}"],"command":"HarperRecordLint","title":"Record lint statistic"},
          "edit":{"changes":{"untitled:grammar-review-1":[{"newText":"a","range":{"end":{"character":10,"line":0},"start":{"character":8,"line":0}}}]}},
          "kind":"quickfix","title":"Replace with: “a”"},
         {"arguments":["untitled:grammar-review-1",{"lint_kind":"Miscellaneous","message":"Incorrect indefinite article.","priority":31,"span":{"end":10,"start":8}}],
          "command":"HarperIgnoreLint","title":"Ignore Harper error."}]
        """;

    [Fact]
    public void HarpersActionsGiveTheFixAndKind()
    {
        var actions = LspCodeAction.ListFrom(JsonNode.Parse(CodeActions));
        Assert.Equal(2, actions.Count);
        Assert.Equal("Miscellaneous", actions[1].LintKind);
        const string text = "This is an test.";
        var diagnostic = new LspDiagnostic(Range(0, 8, 10), "Incorrect indefinite article.", "AnA");
        var lint = HarperLint.From(diagnostic, actions, Uri, new LspLineIndex(text), text);
        Assert.Equal(new TextSpan(8, 2), lint!.Range);
        Assert.Equal(["a"], lint.Replacements);
        Assert.Equal("Miscellaneous", lint.Kind);
        Assert.Equal("AnA", lint.Rule);
    }

    [Fact]
    public void OverlappingLintsKeepTheirOwnFixes()
    {
        const string text = "the the cat";
        var repeated = new LspDiagnostic(Range(0, 0, 7), "Did you mean to repeat this word?", "RepeatedWords");
        var capital = new LspDiagnostic(Range(0, 0, 3), "Capitalize the first word.", "SentenceCapitalization");
        var actions = new[] { Fix(Range(0, 0, 7), "the"), Ignore("Repetition", repeated.Message), Fix(Range(0, 0, 3), "The"), Ignore("Capitalization", capital.Message) };
        var lines = new LspLineIndex(text);
        Assert.Equal(["the"], HarperLint.From(repeated, actions, Uri, lines, text)!.Replacements);
        Assert.Equal(["The"], HarperLint.From(capital, actions, Uri, lines, text)!.Replacements);
    }

    [Fact]
    public void EditsBeyondTheDiagnosticWidenTheLint()
    {
        const string text = "Its fine.";
        var diagnostic = new LspDiagnostic(Range(0, 0, 3), "Use it's.", null);
        var twoEdits = new LspCodeAction("Two", new Dictionary<string, IReadOnlyList<LspTextEdit>>
        {
            [Uri] = [new LspTextEdit(Range(0, 0, 3), "It is"), new LspTextEdit(Range(0, 3, 4), " really ")],
        });
        var lint = HarperLint.From(diagnostic, [Fix(Range(0, 2, 2), "'"), twoEdits], Uri, new LspLineIndex(text), text);
        Assert.Equal(new TextSpan(0, 4), lint!.Range);
        Assert.Equal(["It's ", "It is really "], lint.Replacements);
    }

    [Fact]
    public void DialectsFollowTheRegion()
    {
        Assert.Equal(HarperDialect.British, HarperDialects.For("en-GB", []));
        Assert.Equal(HarperDialect.Australian, HarperDialects.For("en", ["lt-LT", "en-AU"]));
        Assert.Equal(HarperDialect.American, HarperDialects.For("en-US", ["en-GB"]));
        Assert.Equal(HarperDialect.British, HarperDialects.For("en-LT", []));
        Assert.Equal(HarperDialect.American, HarperDialects.For(null, []));
        Assert.False(HarperDialects.IsEnglish("lt-LT"));
        var settings = new HarperConfiguration(HarperDialect.Canadian).Settings().ToJsonString();
        Assert.Equal("""{"harper-ls":{"dialect":"Canadian","diagnosticSeverity":"hint","linters":{"SpellCheck":false,"LongSentences":false}}}""", settings);
    }

    [Fact]
    public void TheLocatorTriesTheChosenPathThenPathThenUsualFolders()
    {
        var files = new HashSet<string> { @"C:\Users\me\.cargo\bin\harper-ls.exe", @"D:\tools\harper-ls.exe" };
        var windows = new HarperLocator(new Dictionary<string, string?> { ["PATH"] = @"C:\Windows;D:\tools", ["LOCALAPPDATA"] = @"C:\Users\me\AppData\Local" },
            @"C:\Users\me", files.Contains, windows: true);
        Assert.Equal(new HarperLocation.Found(@"D:\tools\harper-ls.exe"), windows.Locate(""));
        Assert.Equal(new HarperLocation.Found(@"D:\tools\harper-ls.exe"), windows.Locate(@"""D:\tools"""));
        Assert.Equal(new HarperLocation.Invalid(@"E:\nothing.exe"), windows.Locate(@"E:\nothing.exe"));

        var unix = new HarperLocator(new Dictionary<string, string?>(), "/Users/me", path => path == "/Users/me/.cargo/bin/harper-ls", windows: false);
        Assert.Equal(new HarperLocation.Found("/Users/me/.cargo/bin/harper-ls"), unix.Locate(""));
        Assert.Equal(new HarperLocation.Found("/Users/me/.cargo/bin/harper-ls"), unix.Locate("~/.cargo/bin"));
        Assert.Equal(new HarperLocation.Missing(), new HarperLocator(new Dictionary<string, string?>(), "/Users/me", _ => false, windows: false).Locate(""));
    }

    private static HarperLint Lint(string text, string target, string[] replacements, string? kind = "Grammar", string message = "m") =>
        new(new TextSpan(text.IndexOf(target, StringComparison.Ordinal), target.Length), null, kind, message, replacements);

    [Fact]
    public void LintsBecomeLocalIssues()
    {
        const string text = "This is an test. Its fine, see https://example.com/an-test for an test.";
        var issues = HarperChecker.Issues(
        [
            Lint(text, "an", ["a"], "Miscellaneous"),
            Lint(text, "Its", ["It's", "It's ", "Its"], "Punctuation", "Use `it's` here."),
            Lint(text, "an-test", ["a-test"]),
        ], text, []);
        Assert.Equal(["an", "Its"], issues.Select(i => i.OriginalText));
        Assert.Equal([IssueCategory.Grammar, IssueCategory.Punctuation], issues.Select(i => i.Category));
        Assert.Equal(["It's"], issues[1].Replacements);
        Assert.Equal("Use \u201Cit's\u201D here.", issues[1].Message);
        Assert.All(issues, issue => Assert.Equal(IssueSource.Local, issue.Source));
    }

    [Fact]
    public void WhitespaceFixesShowTheirNeighboursUnlessThatOverlapsAnotherIssue()
    {
        const string text = "A good idea , and.  Next";
        var issues = HarperChecker.Issues(
        [
            new HarperLint(new TextSpan(11, 1), null, "Punctuation", "No space before a comma.", [""]),
            new HarperLint(new TextSpan(18, 2), null, "Formatting", "French spaces.", [" "]),
        ], text, []);
        Assert.Equal(["idea ,", "and.  Next"], issues.Select(i => i.OriginalText));
        Assert.Equal(["idea,", "and. Next"], issues.Select(i => i.Replacements[0]));

        const string next = "Teh , and";
        var spelling = new TextIssue(new TextSpan(0, 3), "Teh", ["The"], "m", IssueCategory.Spelling, IssueSource.Local);
        var narrow = HarperChecker.Issues([new HarperLint(new TextSpan(3, 1), null, "Punctuation", "m", [""])], next, [spelling]);
        Assert.Equal(" ", Assert.Single(narrow).OriginalText);
    }

    [Fact]
    public async Task OnlyEnglishTextIsLintedWhenHarperIsOnAndInstalled()
    {
        var linter = new FakeLinter(text => [Lint(text, "an", ["a"])]);
        var installed = new HarperLocator(new Dictionary<string, string?>(), "/Users/me", path => path == "/opt/homebrew/bin/harper-ls", windows: false);
        var checker = new HarperChecker(linter, installed);
        var settings = new AppSettings();

        Assert.Single(await checker.IssuesAsync("This is an test.", "en-GB", settings, [], CancellationToken.None));
        Assert.Equal(HarperDialect.British, linter.Calls.Single().Dialect);
        Assert.Empty(await checker.IssuesAsync("Tai yra testas.", "lt-LT", settings, [], CancellationToken.None));
        Assert.Empty(await checker.IssuesAsync("This is an test.", "en", settings with { HarperEnabled = false }, [], CancellationToken.None));
        var missing = new HarperChecker(linter, new HarperLocator(new Dictionary<string, string?>(), "/Users/me", _ => false, windows: false));
        Assert.Empty(await missing.IssuesAsync("This is an test.", "en", settings, [], CancellationToken.None));
        Assert.Single(linter.Calls);

        var failing = new HarperChecker(new FakeLinter(_ => throw new HarperException(HarperErrorKind.TimedOut)), installed);
        Assert.Empty(await failing.IssuesAsync("This is an test.", "en", settings, [], CancellationToken.None));
    }

    internal sealed class FakeLinter(Func<string, IReadOnlyList<HarperLint>> lint) : IHarperLinter
    {
        public List<(string Text, HarperDialect Dialect)> Calls { get; } = [];

        public Task<IReadOnlyList<HarperLint>> LintAsync(string text, HarperConfiguration configuration, string executable, CancellationToken cancellation)
        {
            Calls.Add((text, configuration.Dialect));
            return Task.FromResult(lint(text));
        }
    }
}

public class HarperClientTests
{
    private static string? Installed() => new HarperLocator().Locate("") is HarperLocation.Found(var path) ? path : null;

    [Fact]
    public async Task AServerThatExitsFailsFastAndIsNotRestartedRightAway()
    {
        Assert.SkipWhen(OperatingSystem.IsWindows() || !File.Exists("/usr/bin/false"), "needs /usr/bin/false");
        using var client = new HarperClient();
        var configuration = new HarperConfiguration(HarperDialect.American);
        var first = await Assert.ThrowsAsync<HarperException>(() => client.LintAsync("This is an test.", configuration, "/usr/bin/false", CancellationToken.None));
        Assert.Contains(first.Kind, new[] { HarperErrorKind.Stopped, HarperErrorKind.TimedOut });
        var second = await Assert.ThrowsAsync<HarperException>(() => client.LintAsync("This is an test.", configuration, "/usr/bin/false", CancellationToken.None));
        Assert.Equal(HarperErrorKind.BackingOff, second.Kind);
    }

    [Fact]
    public async Task AMissingProgramCannotBeLaunched()
    {
        using var client = new HarperClient();
        var error = await Assert.ThrowsAsync<HarperException>(() =>
            client.LintAsync("Text.", new HarperConfiguration(HarperDialect.American), Path.Combine(Path.GetTempPath(), "no-such-harper-ls"), CancellationToken.None));
        Assert.Equal(HarperErrorKind.LaunchFailed, error.Kind);
    }

    [Fact]
    public async Task LintsWithTheInstalledHarper()
    {
        var executable = Installed();
        Assert.SkipWhen(executable is null, "harper-ls is not installed");
        using var client = new HarperClient();
        const string text = "First line is fine.\r\nThis is an test of the the checker 😀. Their going to the store.";
        var lints = await client.LintAsync(text, new HarperConfiguration(HarperDialect.American), executable!, CancellationToken.None);
        var byText = lints.GroupBy(l => text.Substring(l.Range.Start, l.Range.Length)).ToDictionary(g => g.Key, g => g.First());
        Assert.Equal(["a"], byText["an"].Replacements);
        Assert.Equal("Miscellaneous", byText["an"].Kind);
        Assert.Equal("the", byText["the the"].Replacements[0]);
        Assert.Equal("They're", byText["Their"].Replacements[0]);
        Assert.DoesNotContain(lints, l => l.Rule == "SpellCheck");

        var british = await client.LintAsync("Everything here is fine.", new HarperConfiguration(HarperDialect.British), executable!, CancellationToken.None);
        Assert.Empty(british);

        using var cancelled = new CancellationTokenSource();
        await cancelled.CancelAsync();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => client.LintAsync("This is an test.", new HarperConfiguration(HarperDialect.British), executable!, cancelled.Token));
        Assert.Single(await client.LintAsync("This is an test.", new HarperConfiguration(HarperDialect.British), executable!, CancellationToken.None));

        var installation = await HarperProbe.InstallationAsync(executable!, cancellation: TestContext.Current.CancellationToken);
        var found = Assert.IsType<HarperInstallation.Found>(installation);
        Assert.True(char.IsDigit(found.Version[0]));
    }

    [Fact]
    public void VersionsAreReadFromTheOutput()
    {
        Assert.Equal("2.13.0", HarperProbe.Version("harper-ls 2.13.0\n"));
        Assert.Equal("unknown", HarperProbe.Version(""));
    }
}
