using GrammarReview.Core.Issues;

namespace GrammarReview.Core.Text;

/// <summary>Moves issues found in an older text onto the current one, dropping those whose words were edited.</summary>
public static class IssueRebaser
{
    public static IReadOnlyList<TextIssue> Rebase(IReadOnlyList<TextIssue> issues, string oldText, string newText)
    {
        if (issues.Count == 0) return issues;
        if (oldText == newText) return issues.Where(issue => IsValid(issue, newText)).ToList();
        var diff = TextDiff.Between(oldText, newText);
        var moved = new List<TextIssue>();
        foreach (var issue in issues)
        {
            if (RebasedRange(issue.Range, diff, oldText, newText) is not { } range) continue;
            var candidate = issue with { Range = range };
            if (IsValid(candidate, newText)) moved.Add(candidate);
        }
        return moved;
    }

    public readonly record struct TextDiff(int Prefix, int OldEnd, int NewEnd)
    {
        public int Delta => NewEnd - OldEnd;

        public static TextDiff Between(string oldText, string newText)
        {
            var shorter = Math.Min(oldText.Length, newText.Length);
            var prefix = 0;
            while (prefix < shorter && oldText[prefix] == newText[prefix]) prefix++;
            if (prefix > 0 && char.IsHighSurrogate(oldText[prefix - 1])) prefix--;
            var suffix = 0;
            while (suffix < shorter - prefix && oldText[oldText.Length - 1 - suffix] == newText[newText.Length - 1 - suffix]) suffix++;
            if (suffix > 0 && char.IsLowSurrogate(oldText[oldText.Length - suffix])) suffix--;
            return new TextDiff(prefix, oldText.Length - suffix, newText.Length - suffix);
        }
    }

    public static TextSpan? RebasedRange(TextSpan range, TextDiff diff, string oldText, string newText)
    {
        var start = range.Start;
        var end = range.End;
        if (range.Length <= 0 || !range.Fits(oldText)) return null;
        if (end < diff.Prefix) return range;
        if (start > diff.OldEnd) return range with { Start = start + diff.Delta };
        if (start < diff.OldEnd && end > diff.Prefix) return null;
        if (end == diff.Prefix)
        {
            var extendsWord = TextUnits.IsWordCharacter(oldText, end - 1) && TextUnits.IsWordCharacter(newText, diff.Prefix);
            return extendsWord ? null : range;
        }
        var newStart = start + diff.Delta;
        var extendsBefore = TextUnits.IsWordCharacter(oldText, start) && TextUnits.IsWordCharacter(newText, newStart - 1);
        return extendsBefore ? null : range with { Start = newStart };
    }

    public static bool IsValid(TextIssue issue, string text) =>
        issue.Range.Length > 0 && TextUnits.IsAligned(issue.Range, text) && TextUnits.Substring(text, issue.Range) == issue.OriginalText;
}
