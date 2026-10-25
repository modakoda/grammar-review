using System.Drawing.Drawing2D;

namespace GrammarReview.Windows.Overlay;

/// <summary>A small round badge inside the field's bottom-right corner: the issue count, "…" while checking, "!" on a problem.</summary>
internal sealed class BadgeWindow : OverlayForm
{
    public const int Diameter = 22;

    private readonly Font _font = new("Segoe UI", 8.5f, FontStyle.Bold);
    private string _label = "";
    private Color _color = Palette.Good;

    public BadgeWindow()
    {
        BackColor = Palette.Transparent;
        TransparencyKey = Palette.Transparent;
        DoubleBuffered = true;
        Cursor = Cursors.Hand;
    }

    public void Place(Rectangle field, string label, Color color, string tooltip)
    {
        _label = label;
        _color = color;
        AccessibleName = tooltip;
        var scaled = (int)Math.Round(Diameter * DeviceDpi / 96.0);
        var inset = (int)Math.Round(4 * DeviceDpi / 96.0);
        ShowAt(new Rectangle(field.Right - scaled - inset, field.Bottom - scaled - inset, scaled, scaled));
        Invalidate();
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        e.Graphics.SmoothingMode = SmoothingMode.None;
        using var brush = new SolidBrush(_color);
        e.Graphics.FillEllipse(brush, 0, 0, Width - 1, Height - 1);
        TextRenderer.DrawText(e.Graphics, _label, _font, ClientRectangle, Color.White, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) _font.Dispose();
        base.Dispose(disposing);
    }
}
