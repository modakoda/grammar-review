using System.Text.Json.Nodes;
using GrammarReview.Core.Text;

namespace GrammarReview.Core.Harper;

public sealed record HarperLint(TextSpan Range, string? Rule, string? Kind, string Message, IReadOnlyList<string> Replacements)
{
    public static HarperLint? From(LspDiagnostic diagnostic, IReadOnlyList<LspCodeAction> actions, string uri, LspLineIndex lines, string text)
    {
        if (lines.Span(diagnostic.Range) is not { } baseSpan || !baseSpan.Fits(text)) return null;
        var own = LspCodeAction.For(diagnostic, actions);
        var fixes = new List<List<(TextSpan Span, string NewText)>>();
        foreach (var action in own)
        {
            if (!action.Edits.TryGetValue(uri, out var edits) || edits.Count == 0) continue;
            var spans = edits.Select(edit => (Span: lines.Span(edit.Range), edit.NewText)).ToList();
            if (spans.Any(edit => edit.Span is null)) continue;
            fixes.Add(spans.Select(edit => (edit.Span!.Value, edit.NewText)).ToList());
        }
        var covered = fixes.SelectMany(fix => fix.Select(edit => edit.Span)).Aggregate(baseSpan, TextSpan.Union);
        if (!covered.Fits(text)) return null;
        var original = text.Substring(covered.Start, covered.Length);
        var replacements = new List<string>();
        foreach (var fix in fixes)
        {
            if (Apply(fix, original, covered.Start) is { } result && result != original && !replacements.Contains(result)) replacements.Add(result);
        }
        return new HarperLint(covered, diagnostic.Code, own.Select(action => action.LintKind).FirstOrDefault(kind => kind is not null), diagnostic.Message, replacements);
    }

    private static string? Apply(List<(TextSpan Span, string NewText)> fix, string original, int offset)
    {
        var result = original;
        foreach (var (span, newText) in fix.OrderByDescending(edit => edit.Span.Start))
        {
            var local = span.Start - offset;
            if (local < 0 || local + span.Length > result.Length) return null;
            result = string.Concat(result.AsSpan(0, local), newText, result.AsSpan(local + span.Length));
        }
        return result;
    }
}

public enum HarperDialect
{
    American,
    British,
    Australian,
    Canadian,
    Indian,
}

public static class HarperDialects
{
    public static HarperDialect For(string? language, IEnumerable<string> preferredLanguages)
    {
        var english = new[] { language }.Concat(preferredLanguages).OfType<string>().Where(IsEnglish);
        var region = english.Select(Region).FirstOrDefault(r => r is not null);
        return region switch
        {
            null or "US" or "PH" or "PR" => HarperDialect.American,
            "AU" or "NZ" => HarperDialect.Australian,
            "CA" => HarperDialect.Canadian,
            "IN" => HarperDialect.Indian,
            _ => HarperDialect.British,
        };
    }

    public static bool IsEnglish(string? language) =>
        language is not null && (language.Equals("en", StringComparison.OrdinalIgnoreCase)
            || language.StartsWith("en-", StringComparison.OrdinalIgnoreCase) || language.StartsWith("en_", StringComparison.OrdinalIgnoreCase));

    private static string? Region(string language) =>
        language.Split('-', '_').Skip(1).FirstOrDefault(part => part.Length == 2 && part.All(char.IsLetter))?.ToUpperInvariant();
}

public sealed record HarperConfiguration(HarperDialect Dialect)
{
    // Windows checks spelling in every language; long sentences aren't mistakes.
    public static IReadOnlyList<string> DisabledLinters { get; } = ["SpellCheck", "LongSentences"];

    public JsonObject Settings()
    {
        var linters = new JsonObject();
        foreach (var linter in DisabledLinters) linters[linter] = false;
        return new JsonObject
        {
            ["harper-ls"] = new JsonObject
            {
                ["dialect"] = Dialect.ToString(),
                ["diagnosticSeverity"] = "hint",
                ["linters"] = linters,
            },
        };
    }
}
