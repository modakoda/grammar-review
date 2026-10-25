using System.Text.RegularExpressions;

namespace GrammarReview.Core.Text;

/// <summary>Code, URLs, email addresses and @mentions: text that no checker should flag.</summary>
public static partial class ProtectedRanges
{
    public static IReadOnlyList<TextSpan> Find(string text)
    {
        var spans = new List<TextSpan>();
        foreach (var pattern in new[] { CodeBlock(), InlineCode(), Url(), Www(), Email(), Mention() })
        {
            foreach (Match match in pattern.Matches(text)) spans.Add(new TextSpan(match.Index, match.Length));
        }
        foreach (Match match in Token().Matches(text))
        {
            if (LooksLikeCode(match.Value.Trim(TokenEdges))) spans.Add(new TextSpan(match.Index, match.Length));
        }
        return spans;
    }

    public static bool LooksLikeCode(string token)
    {
        if (token.Length == 0) return false;
        if (token[0] is '@' or '#') return token.Length > 1;
        if (token[0] == '.' && token.Length > 1) return true;
        var previousWasLower = false;
        for (var index = 0; index < token.Length; index++)
        {
            var c = token[index];
            if (char.IsDigit(c) || c == '_' || CodeSymbols.Contains(c)) return true;
            if (char.IsUpper(c) && previousWasLower) return true;
            previousWasLower = char.IsLower(c);
            if (c == '.' && index > 0 && index < token.Length - 1 && char.IsLetterOrDigit(token[index - 1]) && char.IsLetterOrDigit(token[index + 1]))
            {
                return true;
            }
        }
        return token.Contains("::", StringComparison.Ordinal) || token.Contains("->", StringComparison.Ordinal) || token.Contains("()", StringComparison.Ordinal);
    }

    private const string CodeSymbols = "/\\=<>{}[]|~^$%&*+";
    private static readonly char[] TokenEdges = "\"'“”‘’«»„‚()[]{}<>*_~.,;:!?…¿¡".ToCharArray();

    [GeneratedRegex(@"```[\s\S]*?(?:```|\z)")]
    private static partial Regex CodeBlock();

    [GeneratedRegex(@"`[^`\n]+`")]
    private static partial Regex InlineCode();

    [GeneratedRegex(@"\b[A-Za-z][A-Za-z0-9+.-]*://[^\s<>""]+")]
    private static partial Regex Url();

    [GeneratedRegex(@"\bwww\.[^\s<>""]+")]
    private static partial Regex Www();

    [GeneratedRegex(@"[\p{L}\p{N}._%+-]+@[\p{L}\p{N}-]+(?:\.[\p{L}\p{N}-]+)+")]
    private static partial Regex Email();

    [GeneratedRegex(@"(?<![\p{L}\p{N}_])[@#][\p{L}\p{N}_][\p{L}\p{N}_.-]*")]
    private static partial Regex Mention();

    [GeneratedRegex(@"\S+")]
    private static partial Regex Token();
}
