using System.Globalization;
using System.Text;

namespace GrammarReview.Core.Text;

public static class TextUnits
{
    public static bool IsWordCharacter(string text, int index)
    {
        if (index < 0 || index >= text.Length) return false;
        var c = text[index];
        if (char.IsLowSurrogate(c) && index > 0) return IsWordCharacter(text, index - 1);
        if (char.IsHighSurrogate(c))
        {
            return index + 1 < text.Length && Rune.TryCreate(c, text[index + 1], out var rune) && Rune.IsLetterOrDigit(rune);
        }
        return char.IsLetterOrDigit(c) || c == '\'' || c == '\u2019' || CharUnicodeInfo.GetUnicodeCategory(c) == UnicodeCategory.NonSpacingMark;
    }

    /// <summary>True when the span doesn't start or end inside a surrogate pair.</summary>
    public static bool IsAligned(TextSpan span, string text)
    {
        if (!span.Fits(text)) return false;
        if (span.Start > 0 && span.Start < text.Length && char.IsLowSurrogate(text[span.Start])) return false;
        return span.End <= 0 || span.End >= text.Length || !char.IsLowSurrogate(text[span.End]);
    }

    public static string? Substring(string text, TextSpan span) => span.Fits(text) ? text.Substring(span.Start, span.Length) : null;

    public static bool IsLineBreak(char c) => c is '\n' or '\r' or '\u2028' or '\u2029';
}
