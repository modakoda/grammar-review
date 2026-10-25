using GrammarReview.Core.Issues;

namespace GrammarReview.Windows.Overlay;

internal static class Palette
{
    public static readonly Color Correctness = Color.FromArgb(229, 72, 77);
    public static readonly Color ClarityColor = Color.FromArgb(62, 99, 221);
    public static readonly Color StyleColor = Color.FromArgb(142, 78, 198);
    public static readonly Color Good = Color.FromArgb(48, 164, 108);
    public static readonly Color Warning = Color.FromArgb(230, 126, 34);
    public static readonly Color Card = Color.FromArgb(252, 252, 253);
    public static readonly Color Border = Color.FromArgb(222, 222, 228);
    public static readonly Color Muted = Color.FromArgb(96, 100, 108);
    public static readonly Color Pill = Color.FromArgb(240, 242, 247);

    // Pure magenta never appears in the underlines, so it can be the see-through colour.
    public static readonly Color Transparent = Color.FromArgb(255, 0, 255);

    public static Color For(IssueSeverity severity) => severity switch
    {
        IssueSeverity.Correctness => Correctness,
        IssueSeverity.Clarity => ClarityColor,
        _ => StyleColor,
    };

    public static Color For(IssueCategory category) => For(category.Severity());
}
