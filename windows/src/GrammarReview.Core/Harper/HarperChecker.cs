using System.Text.RegularExpressions;
using GrammarReview.Core.Issues;
using GrammarReview.Core.Settings;
using GrammarReview.Core.Text;

namespace GrammarReview.Core.Harper;

/// <summary>Turns Harper's lints into local issues for English text, leaving code, URLs and other local issues alone.</summary>
public sealed partial class HarperChecker(IHarperLinter? linter, HarperLocator? locator = null)
{
    public const int MaxLength = 100_000;
    public const int MaxReplacements = 3;
    public const int MaxWidening = 40;

    private readonly HarperLocator _locator = locator ?? new HarperLocator();

    public async Task<IReadOnlyList<TextIssue>> IssuesAsync(string text, string? language, AppSettings settings, IReadOnlyList<TextIssue> found, CancellationToken cancellation)
    {
        if (linter is null || !settings.HarperEnabled || text.Length > MaxLength || !HarperDialects.IsEnglish(language)) return [];
        if (_locator.Locate(settings.HarperPath) is not HarperLocation.Found(var executable)) return [];
        var configuration = new HarperConfiguration(HarperDialects.For(language, []));
        try
        {
            var lints = await linter.LintAsync(text, configuration, executable, cancellation).ConfigureAwait(false);
            return cancellation.IsCancellationRequested ? [] : Issues(lints, text, found);
        }
        catch (HarperException)
        {
            return [];
        }
    }

    public static IReadOnlyList<TextIssue> Issues(IReadOnlyList<HarperLint> lints, string text, IReadOnlyList<TextIssue> found)
    {
        var blocked = ProtectedRanges.Find(text).Concat(found.Select(issue => issue.Range)).ToList();
        var issues = new List<TextIssue>();
        foreach (var lint in lints)
        {
            if (lint.Range.Length <= 0 || !lint.Range.Fits(text) || blocked.Any(lint.Range.Overlaps)) continue;
            var (range, replacements) = (lint.Range, lint.Replacements);
            var widened = Widened(lint, text);
            if (widened.Range != range && !blocked.Any(widened.Range.Overlaps)) (range, replacements) = widened;
            var original = text.Substring(range.Start, range.Length);
            blocked.Add(range);
            issues.Add(new TextIssue(range, original, Distinct(replacements, original).Take(MaxReplacements).ToList(), Quoted(lint.Message), Category(lint.Kind), IssueSource.Local));
        }
        return issues;
    }

    public static IssueCategory Category(string? kind) => kind switch
    {
        "Spelling" or "Typo" => IssueCategory.Spelling,
        "Punctuation" or "Formatting" => IssueCategory.Punctuation,
        "WordChoice" or "Usage" or "Regionalism" => IssueCategory.WordChoice,
        "Readability" or "Redundancy" => IssueCategory.Clarity,
        "Style" or "Enhancement" => IssueCategory.Style,
        _ => IssueCategory.Grammar,
    };

    public static string Quoted(string message) => Code().Replace(message, "“$1”");

    /// <summary>A fix to spaces alone shows the words around them, so the card reads "idea ," → "idea,".</summary>
    public static (TextSpan Range, IReadOnlyList<string> Replacements) Widened(HarperLint lint, string text)
    {
        if (!string.IsNullOrWhiteSpace(text.Substring(lint.Range.Start, lint.Range.Length))) return (lint.Range, lint.Replacements);
        var start = lint.Range.Start;
        for (var steps = 0; steps < MaxWidening && start > 0 && !char.IsWhiteSpace(text[start - 1]) && !char.IsSurrogate(text[start - 1]); steps++) start--;
        var end = lint.Range.End;
        for (var steps = 0; steps < MaxWidening && end < text.Length && !char.IsWhiteSpace(text[end]) && !char.IsSurrogate(text[end]); steps++) end++;
        var range = new TextSpan(start, end - start);
        if (range == lint.Range) return (lint.Range, lint.Replacements);
        var before = text[start..lint.Range.Start];
        var after = text[lint.Range.End..end];
        return (range, lint.Replacements.Select(replacement => before + replacement + after).ToList());
    }

    private static IEnumerable<string> Distinct(IEnumerable<string> replacements, string original)
    {
        var seen = new HashSet<string>(StringComparer.Ordinal);
        return replacements.Where(replacement => replacement != original && seen.Add(replacement.Trim()));
    }

    [GeneratedRegex("`([^`\n]+)`")]
    private static partial Regex Code();
}
