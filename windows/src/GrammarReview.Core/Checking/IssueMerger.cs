using GrammarReview.Core.Issues;
using GrammarReview.Core.Settings;
using GrammarReview.Core.Text;

namespace GrammarReview.Core.Checking;

/// <summary>Combines local and AI issues: AI wins where they overlap, except that local spelling guesses join the AI's.</summary>
public static class IssueMerger
{
    public static IReadOnlyList<TextIssue> Merge(IReadOnlyList<TextIssue> local, IReadOnlyList<TextIssue> ai, AppSettings settings)
    {
        var aiIssues = ai.ToList();
        var kept = new List<TextIssue>();
        foreach (var issue in local)
        {
            var overlapping = Enumerable.Range(0, aiIssues.Count).Where(i => aiIssues[i].Range.Overlaps(issue.Range)).ToList();
            if (overlapping.Count == 0)
            {
                kept.Add(issue);
                continue;
            }
            if (issue.Category != IssueCategory.Spelling) continue;
            foreach (var index in overlapping.Where(i => aiIssues[i].Category == IssueCategory.Spelling && aiIssues[i].Range == issue.Range))
            {
                aiIssues[index] = aiIssues[index] with { Replacements = Deduplicated(aiIssues[index].Replacements.Concat(issue.Replacements)) };
            }
        }

        var seen = new HashSet<TextSpan>();
        return aiIssues.Concat(kept)
            .Where(issue => settings.EnabledCategories.Contains(issue.Category))
            .Where(issue => issue.Category != IssueCategory.Spelling || !settings.IsInPersonalDictionary(issue.OriginalText.Trim()))
            .Where(issue => seen.Add(issue.Range))
            .OrderBy(issue => issue.Range.Start).ThenBy(issue => issue.Range.Length)
            .ToList();
    }

    public static IReadOnlyList<string> Deduplicated(IEnumerable<string> values)
    {
        var seen = new HashSet<string>(StringComparer.Ordinal);
        return values.Where(seen.Add).ToList();
    }
}
