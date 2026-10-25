using System.Drawing.Drawing2D;

namespace GrammarReview.Windows.Overlay;

/// <summary>A click-through window over the field that draws wavy underlines under each issue.</summary>
internal sealed class UnderlineWindow : OverlayForm
{
    public const int Inset = 4;

    private IReadOnlyList<(Rectangle Rect, Color Color)> _lines = [];

    public UnderlineWindow()
    {
        BackColor = Palette.Transparent;
        TransparencyKey = Palette.Transparent;
        DoubleBuffered = true;
    }

    protected override bool ClickThrough => true;

    /// <summary>Draws the underlines; <paramref name="lines"/> and <paramref name="field"/> are in screen pixels.</summary>
    public void Draw(Rectangle field, IReadOnlyList<(Rectangle Rect, Color Color)> lines)
    {
        if (lines.Count == 0)
        {
            Hide();
            return;
        }
        var bounds = Rectangle.Inflate(field, Inset, Inset);
        _lines = lines.Where(line => bounds.IntersectsWith(line.Rect)).ToList();
        ShowAt(bounds);
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.None;
        foreach (var (rect, color) in _lines)
        {
            using var pen = new Pen(color, 1.6f);
            var left = rect.Left - Left;
            var right = rect.Right - Left;
            var baseline = Math.Min(rect.Bottom - Top, Height - 3);
            var points = new List<Point>();
            for (var x = left; x <= right; x += 2) points.Add(new Point(x, baseline + ((x - left) / 2 % 2 == 0 ? 0 : -2)));
            if (points.Count > 1) e.Graphics.DrawLines(pen, points.ToArray());
        }
    }
}
