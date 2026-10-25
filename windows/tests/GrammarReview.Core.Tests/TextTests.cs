using GrammarReview.Core.Issues;
using GrammarReview.Core.Text;

namespace GrammarReview.Core.Tests;

public class TextTests
{
    private static TextIssue Issue(string text, string word) =>
        new(new TextSpan(text.IndexOf(word, StringComparison.Ordinal), word.Length), word, ["x"], "m", IssueCategory.Spelling, IssueSource.Local);

    [Fact]
    public void ParagraphsKeepTheirUtf16Offsets()
    {
        const string text = "First line\n\nSecond line\r\nThird\u2028Fourth";
        var paragraphs = ParagraphSplitter.Split(text);
        Assert.Equal(["First line", "Second line", "Third", "Fourth"], paragraphs.Select(p => p.Text));
        Assert.Equal([0, 12, 25, 31], paragraphs.Select(p => p.Start));
        Assert.All(paragraphs, p => Assert.Equal(p.Text, text.Substring(p.Start, p.Text.Length)));
        Assert.Equal([new Paragraph("Next", 5)], ParagraphSplitter.Split("😀😀\nNext").Skip(1));
        Assert.Empty(ParagraphSplitter.Split("  \n\t\n"));
    }

    [Fact]
    public void IssuesFollowTypingElsewhere()
    {
        const string old = "I has teh cat.";
        var issues = new[] { Issue(old, "has"), Issue(old, "teh") };
        var moved = IssueRebaser.Rebase(issues, old, "Now I has teh cat.");
        Assert.Equal([6, 10], moved.Select(i => i.Range.Start));
        Assert.Equal(issues.Select(i => i.Id), moved.Select(i => i.Id));
    }

    [Fact]
    public void EditedWordsLoseTheirIssues()
    {
        const string old = "I has teh cat.";
        var issues = new[] { Issue(old, "has"), Issue(old, "teh") };
        Assert.Equal(["has"], IssueRebaser.Rebase(issues, old, "I has the cat.").Select(i => i.OriginalText));
        Assert.Equal(["teh"], IssueRebaser.Rebase(issues, old, "I hasn teh cat.").Select(i => i.OriginalText));
        Assert.Equal(["has", "teh"], IssueRebaser.Rebase(issues, old, "I has teh cats.").Select(i => i.OriginalText));
    }

    [Fact]
    public void CodeUrlsAndMentionsAreProtected()
    {
        const string text = "See https://example.com/a_b, `code here`, mail me@example.com, ping @anna, call fooBar() and v2.";
        var protectedText = ProtectedRanges.Find(text).Select(span => text.Substring(span.Start, span.Length)).ToList();
        Assert.Contains("https://example.com/a_b,", protectedText);
        Assert.Contains("`code here`", protectedText);
        Assert.Contains("me@example.com", protectedText);
        Assert.Contains("@anna", protectedText);
        Assert.Contains("fooBar()", protectedText);
        Assert.Contains("v2.", protectedText);
        Assert.DoesNotContain("See", protectedText);
    }

    [Fact]
    public void WordCharactersIncludeApostrophesAndAstralLetters()
    {
        Assert.True(TextUnits.IsWordCharacter("don't", 3));
        Assert.True(TextUnits.IsWordCharacter("a𝒜b", 1));
        Assert.True(TextUnits.IsWordCharacter("a𝒜b", 2));
        Assert.False(TextUnits.IsWordCharacter("a b", 1));
        Assert.False(TextUnits.IsAligned(new TextSpan(2, 1), "a😀b"));
        Assert.True(TextUnits.IsAligned(new TextSpan(1, 2), "a😀b"));
    }
}
