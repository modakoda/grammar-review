namespace GrammarReview.Core.Text;

/// <summary>A range of UTF-16 code units, the units of .NET strings and of UI Automation text.</summary>
public readonly record struct TextSpan(int Start, int Length)
{
    public int End => Start + Length;

    public bool Overlaps(TextSpan other) => Start < other.End && other.Start < End;

    public bool Contains(TextSpan other) => other.Start >= Start && other.End <= End;

    public bool Fits(string text) => Start >= 0 && Length >= 0 && End <= text.Length;

    public static TextSpan Union(TextSpan a, TextSpan b)
    {
        var start = Math.Min(a.Start, b.Start);
        return new TextSpan(start, Math.Max(a.End, b.End) - start);
    }

    public override string ToString() => $"[{Start}, {End})";
}
