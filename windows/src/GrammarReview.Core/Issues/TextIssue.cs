using GrammarReview.Core.Text;

namespace GrammarReview.Core.Issues;

public enum IssueCategory
{
    Spelling,
    Grammar,
    Punctuation,
    WordChoice,
    Clarity,
    Style,
}

public enum IssueSeverity
{
    Correctness,
    Clarity,
    Style,
}

public enum IssueSource
{
    Local,
    AI,
}

public static class IssueCategories
{
    public static IReadOnlyList<IssueCategory> All { get; } = Enum.GetValues<IssueCategory>();

    public static IssueSeverity Severity(this IssueCategory category) => category switch
    {
        IssueCategory.Spelling or IssueCategory.Grammar or IssueCategory.Punctuation => IssueSeverity.Correctness,
        IssueCategory.WordChoice or IssueCategory.Clarity => IssueSeverity.Clarity,
        _ => IssueSeverity.Style,
    };

    public static string DisplayName(this IssueCategory category) => category switch
    {
        IssueCategory.Spelling => "Spelling",
        IssueCategory.Grammar => "Grammar",
        IssueCategory.Punctuation => "Punctuation",
        IssueCategory.WordChoice => "Word choice",
        IssueCategory.Clarity => "Clarity",
        _ => "Style",
    };

    /// <summary>The name in the AI's JSON, the same as the macOS app's.</summary>
    public static string WireName(this IssueCategory category) => category switch
    {
        IssueCategory.WordChoice => "wordChoice",
        _ => category.ToString().ToLowerInvariant(),
    };

    public static IssueCategory FromWire(string? name)
    {
        if (string.IsNullOrWhiteSpace(name)) return IssueCategory.Grammar;
        var squashed = new string(name.Where(char.IsLetter).ToArray());
        return All.FirstOrDefault(c => string.Equals(c.WireName(), squashed, StringComparison.OrdinalIgnoreCase), IssueCategory.Grammar);
    }
}

public sealed record TextIssue(
    TextSpan Range,
    string OriginalText,
    IReadOnlyList<string> Replacements,
    string Message,
    IssueCategory Category,
    IssueSource Source)
{
    public Guid Id { get; init; } = Guid.NewGuid();

    public string Fingerprint => $"{Category}|{OriginalText}|{(Replacements.Count > 0 ? Replacements[0] : "")}";
}
