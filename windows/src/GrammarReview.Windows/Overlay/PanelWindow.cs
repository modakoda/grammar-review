using GrammarReview.Core.Issues;

namespace GrammarReview.Windows.Overlay;

/// <summary>Every suggestion for the field, opened from the badge or Ctrl+Alt+G, with Fix All for correctness issues.</summary>
internal sealed class PanelWindow : OverlayForm
{
    public const int PanelWidth = 380;

    private readonly FlowLayoutPanel _content = new()
    {
        FlowDirection = FlowDirection.TopDown,
        AutoSize = true,
        AutoSizeMode = AutoSizeMode.GrowAndShrink,
        WrapContents = false,
        Padding = new Padding(12, 10, 12, 8),
        BackColor = Palette.Card,
        MaximumSize = new Size(PanelWidth, 560),
        AutoScroll = true,
    };

    public PanelWindow()
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

    public void Show(IReadOnlyList<TextIssue> issues, string? status, Rectangle anchor, CardActions actions, Action fixAll, Action close)
    {
        _content.SuspendLayout();
        Clear(_content);
        var header = new FlowLayoutPanel { AutoSize = true, Margin = new Padding(0, 0, 0, 6), BackColor = Palette.Card };
        header.Controls.Add(new Label
        {
            Text = issues.Count switch { 0 => "No suggestions", 1 => "1 suggestion", _ => $"{issues.Count} suggestions" },
            AutoSize = true,
            Font = _title,
            Margin = new Padding(0, 2, 12, 0),
        });
        var fixable = issues.Count(i => i.Category.Severity() == IssueSeverity.Correctness && i.Replacements.Count > 0);
        if (fixable > 1)
        {
            var all = new ClickLabel($"Fix All ({fixable})", Palette.Correctness, Color.White, _bold);
            all.Click += (_, _) => fixAll();
            header.Controls.Add(all);
        }
        var closeLabel = new ClickLabel("Close", Palette.Pill, Palette.Muted);
        closeLabel.Click += (_, _) => close();
        header.Controls.Add(closeLabel);
        _content.Controls.Add(header);
        if (status is not null)
        {
            _content.Controls.Add(new Label { Text = status, AutoSize = true, MaximumSize = new Size(PanelWidth - 30, 0), ForeColor = Palette.Muted, Margin = new Padding(0, 0, 0, 8) });
        }
        foreach (var issue in issues.Take(50))
        {
            _content.Controls.Add(Row(issue, actions));
        }
        _content.ResumeLayout();

        var size = GetPreferredSize(Size.Empty);
        var screen = Screen.FromRectangle(anchor).WorkingArea;
        var left = Math.Clamp(anchor.Right - size.Width, screen.Left, Math.Max(screen.Left, screen.Right - size.Width));
        var top = anchor.Bottom + 6 + size.Height <= screen.Bottom ? anchor.Bottom + 6 : Math.Max(screen.Top, anchor.Top - size.Height - 6);
        ShowAt(new Rectangle(left, top, size.Width, size.Height));
    }

    private Control Row(TextIssue issue, CardActions actions)
    {
        var row = new FlowLayoutPanel
        {
            FlowDirection = FlowDirection.TopDown,
            AutoSize = true,
            WrapContents = false,
            Margin = new Padding(0, 0, 0, 10),
            BackColor = Palette.Card,
        };
        row.Controls.Add(new Label { Text = issue.Category.DisplayName(), AutoSize = true, ForeColor = Palette.For(issue.Category), Font = _bold, Margin = new Padding(0, 0, 0, 2) });
        row.Controls.Add(new Label { Text = issue.Message, AutoSize = true, MaximumSize = new Size(PanelWidth - 30, 0), ForeColor = Palette.Muted, Margin = new Padding(0, 0, 0, 4) });
        var fixes = new FlowLayoutPanel { AutoSize = true, MaximumSize = new Size(PanelWidth - 30, 0), Margin = Padding.Empty, BackColor = Palette.Card };
        fixes.Controls.Add(new Label { Text = issue.OriginalText.Trim().Length == 0 ? "(space)" : issue.OriginalText, AutoSize = true, Font = _strike, ForeColor = Palette.Muted, Margin = new Padding(0, 4, 4, 6) });
        foreach (var replacement in issue.Replacements.Take(3))
        {
            var pill = new ClickLabel(replacement.Length == 0 ? "Remove" : replacement, Palette.For(issue.Category), Color.White);
            pill.Click += (_, _) => actions.Accept(issue, replacement);
            fixes.Controls.Add(pill);
        }
        var ignore = new ClickLabel("Ignore", Palette.Pill, Palette.Muted);
        ignore.Click += (_, _) => actions.Ignore(issue);
        fixes.Controls.Add(ignore);
        row.Controls.Add(fixes);
        return row;
    }
}
