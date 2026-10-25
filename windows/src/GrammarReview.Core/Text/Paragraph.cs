namespace GrammarReview.Core.Text;

public sealed record Paragraph(string Text, int Start)
{
    public TextSpan Span => new(Start, Text.Length);
}

public static class ParagraphSplitter
{
    public const int MinimumLettersForAI = 4;

    public static IReadOnlyList<Paragraph> Split(string text)
    {
        var paragraphs = new List<Paragraph>();
        var lineStart = 0;
        for (var index = 0; index <= text.Length; index++)
        {
            if (index < text.Length && !TextUnits.IsLineBreak(text[index])) continue;
            var first = lineStart;
            var last = index - 1;
            while (first <= last && char.IsWhiteSpace(text[first])) first++;
            while (last >= first && char.IsWhiteSpace(text[last])) last--;
            if (first <= last) paragraphs.Add(new Paragraph(text[first..(last + 1)], first));
            lineStart = index + 1;
        }
        return paragraphs;
    }

    public static bool IsWorthChecking(Paragraph paragraph) => paragraph.Text.Count(char.IsLetter) >= MinimumLettersForAI;
}
