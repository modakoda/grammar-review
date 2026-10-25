using GrammarReview.Core.Issues;

namespace GrammarReview.Windows.Overlay;

internal sealed record CardActions(Action<TextIssue, string> Accept, Action<TextIssue> Ignore, Action<TextIssue> AddToDictionary);

/// <summary>The suggestion card: what's wrong, the fixes to click, Ignore and Add to Dictionary.</summary>
internal sealed class CardWindow : OverlayForm
{
    public const int MaxWidth = 340;

    private readonly FlowLayoutPanel _content = new()
    {
        FlowDirection = FlowDirection.TopDown,
        AutoSize = true,
        AutoSizeMode = AutoSizeMode.GrowAndShrink,
        WrapContents = false,
        Padding = new Padding(12, 10, 12, 6),
        BackColor = Palette.Card,
    };

    public CardWindow()
    {
        BackColor = Palette.Border;
        Padding = new Padding(1);
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        Controls.Add(_content);
        Font = new Font("Segoe UI", 9f);
        _bold = new Font(Font, FontStyle.Bold);
        _strike = new Font(Font, FontStyle.Strikeout);
        _title = new Font(Font.FontFamily, 11f, FontStyle.Bold);
    }

    private readonly Font _bold;
    private readonly Font _strike;
    private readonly Font _title;

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _bold.Dispose();
            _strike.Dispose();
            _title.Dispose();
        }
        base.Dispose(disposing);
    }

    public TextIssue? Issue { get; private set; }

    public void Show(TextIssue issue, Rectangle anchor, CardActions actions)
    {
        Issue = issue;
        _content.SuspendLayout();
        Clear(_content);
        _content.Controls.Add(new Label
        {
            Text = issue.Category.DisplayName(),
            AutoSize = true,
            ForeColor = Palette.For(issue.Category),
            Font = _bold,
            Margin = new Padding(0, 0, 0, 4),
        });
        if (issue.Message.Length > 0)
        {
            _content.Controls.Add(new Label { Text = issue.Message, AutoSize = true, MaximumSize = new Size(MaxWidth, 0), ForeColor = Palette.Muted, Margin = new Padding(0, 0, 0, 8) });
        }
        var fixes = new FlowLayoutPanel { AutoSize = true, MaximumSize = new Size(MaxWidth, 0), Margin = Padding.Empty, BackColor = Palette.Card };
        if (issue.OriginalText.Trim().Length > 0)
        {
            fixes.Controls.Add(new Label { Text = issue.OriginalText, AutoSize = true, Font = _strike, ForeColor = Palette.Muted, Margin = new Padding(0, 4, 4, 6) });
            fixes.Controls.Add(new Label { Text = "→", AutoSize = true, ForeColor = Palette.Muted, Margin = new Padding(0, 4, 4, 6) });
        }
        foreach (var replacement in issue.Replacements)
        {
            var pill = new ClickLabel(replacement.Length == 0 ? "Remove" : replacement, Palette.For(issue.Category), Color.White, _bold);
            pill.Click += (_, _) => actions.Accept(issue, replacement);
            fixes.Controls.Add(pill);
        }
        if (fixes.Controls.Count > 0) _content.Controls.Add(fixes);
        var buttons = new FlowLayoutPanel { AutoSize = true, Margin = Padding.Empty, BackColor = Palette.Card };
        var ignore = new ClickLabel("Ignore", Palette.Pill, Palette.Muted);
        ignore.Click += (_, _) => actions.Ignore(issue);
        buttons.Controls.Add(ignore);
        if (issue.Category == IssueCategory.Spelling)
        {
            var learn = new ClickLabel("Add to Dictionary", Palette.Pill, Palette.Muted);
            learn.Click += (_, _) => actions.AddToDictionary(issue);
            buttons.Controls.Add(learn);
        }
        _content.Controls.Add(buttons);
        _content.ResumeLayout();

        var size = GetPreferredSize(Size.Empty);
        var screen = Screen.FromRectangle(anchor).WorkingArea;
        var top = anchor.Bottom + 6 + size.Height <= screen.Bottom ? anchor.Bottom + 6 : anchor.Top - size.Height - 6;
        var left = Math.Clamp(anchor.Left, screen.Left, Math.Max(screen.Left, screen.Right - size.Width));
        ShowAt(new Rectangle(left, top, size.Width, size.Height));
    }

    public void Dismiss()
    {
        Issue = null;
        Hide();
    }
}
