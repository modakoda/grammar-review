using System.Globalization;
using GrammarReview.Core.Issues;
using GrammarReview.Core.Text;

namespace GrammarReview.Core.Checking;

public sealed record AIEdit(string Original, string Replacement, string ContextBefore, string Explanation, IssueCategory Category);

public sealed record LocatedEdit(TextSpan Range, string OriginalText, AIEdit Edit);

/// <summary>Finds where in a paragraph each of the AI's edits applies, using the text it quoted before the edit.</summary>
public static class EditLocator
{
    public const int MaxOccurrences = 2000;

    public static IReadOnlyList<LocatedEdit> Locate(IReadOnlyList<AIEdit> edits, string paragraph)
    {
        var located = new List<LocatedEdit>();
        foreach (var edit in edits)
        {
            if (edit.Original.Length == 0 || edit.Original == edit.Replacement) continue;
            var candidates = Occurrences(edit.Original, paragraph, literal: true);
            if (candidates.Count == 0) candidates = Occurrences(edit.Original, paragraph, literal: false);
            candidates.RemoveAll(candidate => located.Any(l => l.Range.Overlaps(candidate)));
            if (BestCandidate(candidates, edit, paragraph) is not { } best) continue;
            var originalText = paragraph.Substring(best.Start, best.Length);
            if (originalText == edit.Replacement) continue;
            located.Add(new LocatedEdit(best, originalText, edit));
        }
        return located;
    }

    public static IReadOnlyList<TextIssue> Issues(IReadOnlyList<LocatedEdit> located, int paragraphStart) =>
        located.Select(item => new TextIssue(
            item.Range with { Start = item.Range.Start + paragraphStart },
            item.OriginalText,
            [item.Edit.Replacement],
            string.IsNullOrWhiteSpace(item.Edit.Explanation) ? DefaultMessage(item.Edit.Category) : item.Edit.Explanation,
            item.Edit.Category,
            IssueSource.AI)).ToList();

    public static string DefaultMessage(IssueCategory category) => category switch
    {
        IssueCategory.Spelling => "Possible spelling mistake.",
        IssueCategory.Grammar => "Possible grammar mistake.",
        IssueCategory.Punctuation => "Check the punctuation here.",
        IssueCategory.WordChoice => "Consider a different word.",
        IssueCategory.Clarity => "This could be clearer.",
        _ => "Consider rephrasing.",
    };

    private static List<TextSpan> Occurrences(string needle, string haystack, bool literal)
    {
        var result = new List<TextSpan>();
        var compare = CultureInfo.InvariantCulture.CompareInfo;
        var start = 0;
        while (start < haystack.Length && result.Count < MaxOccurrences)
        {
            int index;
            int length;
            if (literal)
            {
                index = haystack.IndexOf(needle, start, StringComparison.Ordinal);
                length = needle.Length;
            }
            else
            {
                index = compare.IndexOf(haystack.AsSpan(start), needle.AsSpan(), CompareOptions.None, out length);
                if (index >= 0) index += start;
            }
            if (index < 0 || length == 0) break;
            var span = new TextSpan(index, length);
            if (TextUnits.IsAligned(span, haystack)) result.Add(span);
            start = index + (char.IsHighSurrogate(haystack[index]) ? 2 : 1);
        }
        return result;
    }

    private static TextSpan? BestCandidate(List<TextSpan> candidates, AIEdit edit, string text)
    {
        TextSpan? best = null;
        var bestScore = (-1, -1, -1);
        foreach (var candidate in candidates)
        {
            var preceding = PrecedingText(candidate.Start, edit.ContextBefore.Length, text);
            var exact = edit.ContextBefore.Length > 0 && preceding == edit.ContextBefore ? 1 : 0;
            var boundary = IsOnWordBoundaries(candidate, text) ? 1 : 0;
            var score = (exact, boundary, CommonSuffixLength(preceding, edit.ContextBefore));
            if (best is null || score.CompareTo(bestScore) > 0)
            {
                best = candidate;
                bestScore = score;
            }
        }
        return best;
    }

    private static string PrecedingText(int location, int maxLength, string text)
    {
        if (maxLength <= 0 || location <= 0) return "";
        var start = Math.Max(0, location - maxLength);
        if (start > 0 && char.IsLowSurrogate(text[start])) start++;
        return start < location ? text[start..location] : "";
    }

    private static int CommonSuffixLength(string a, string b)
    {
        var count = 0;
        while (count < a.Length && count < b.Length && a[a.Length - 1 - count] == b[b.Length - 1 - count]) count++;
        return count;
    }

    private static bool IsOnWordBoundaries(TextSpan range, string text)
    {
        if (TextUnits.IsWordCharacter(text, range.Start) && range.Start > 0 && TextUnits.IsWordCharacter(text, range.Start - 1)) return false;
        return !(range.End > range.Start && TextUnits.IsWordCharacter(text, range.End - 1) && TextUnits.IsWordCharacter(text, range.End));
    }
}
