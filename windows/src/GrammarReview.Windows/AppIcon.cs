using System.Drawing.Drawing2D;
using System.Drawing.Text;
using GrammarReview.Windows.Native;

namespace GrammarReview.Windows;

/// <summary>Draws the notification-area icon like the Mac app's: a bold G with the red squiggle under it, on a navy tile.</summary>
internal static class AppIcon
{
    public static Icon Create(int size)
    {
        using var bitmap = new Bitmap(size, size);
        using (var graphics = Graphics.FromImage(bitmap))
        {
            graphics.SmoothingMode = SmoothingMode.AntiAlias;
            graphics.TextRenderingHint = TextRenderingHint.AntiAliasGridFit;
            var bounds = new Rectangle(0, 0, size - 1, size - 1);
            using var tile = RoundedRectangle(bounds, (int)(size * 0.225));
            using var fill = new LinearGradientBrush(bounds, Color.FromArgb(43, 56, 97), Color.FromArgb(18, 23, 48), 90f);
            graphics.FillPath(fill, tile);

            using var font = new Font("Georgia", size * 0.62f, FontStyle.Bold, GraphicsUnit.Pixel);
            using var cream = new SolidBrush(Color.FromArgb(250, 245, 232));
            using var format = new StringFormat { Alignment = StringAlignment.Center, LineAlignment = StringAlignment.Center };
            graphics.DrawString("G", font, cream, new RectangleF(0, -size * 0.06f, size, size), format);

            using var squiggle = new Pen(Color.FromArgb(255, 77, 84), Math.Max(1.5f, size * 0.08f)) { StartCap = LineCap.Round, EndCap = LineCap.Round, LineJoin = LineJoin.Round };
            var left = size * 0.27f;
            var right = size * 0.73f;
            var y = size * 0.8f;
            var amplitude = size * 0.05f;
            var step = (right - left) / 3;
            using var wave = new GraphicsPath();
            for (var i = 0; i < 3; i++)
            {
                var start = left + step * i;
                var lift = i % 2 == 0 ? -amplitude : amplitude;
                wave.AddBezier(start, y, start + step / 3, y + lift, start + step * 2 / 3, y + lift, start + step, y);
            }
            graphics.DrawPath(squiggle, wave);
        }
        var handle = bitmap.GetHicon();
        try
        {
            using var borrowed = Icon.FromHandle(handle);
            return (Icon)borrowed.Clone();
        }
        finally
        {
            NativeMethods.DestroyIcon(handle);
        }
    }

    private static GraphicsPath RoundedRectangle(Rectangle bounds, int radius)
    {
        var path = new GraphicsPath();
        var diameter = Math.Max(2, radius * 2);
        path.AddArc(bounds.Left, bounds.Top, diameter, diameter, 180, 90);
        path.AddArc(bounds.Right - diameter, bounds.Top, diameter, diameter, 270, 90);
        path.AddArc(bounds.Right - diameter, bounds.Bottom - diameter, diameter, diameter, 0, 90);
        path.AddArc(bounds.Left, bounds.Bottom - diameter, diameter, diameter, 90, 90);
        path.CloseFigure();
        return path;
    }
}
