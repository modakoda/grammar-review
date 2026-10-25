using GrammarReview.Windows.Native;

namespace GrammarReview.Windows.Overlay;

/// <summary>A topmost window that never takes the focus, so the app being edited stays active.</summary>
internal class OverlayForm : Form
{
    public OverlayForm()
    {
        FormBorderStyle = FormBorderStyle.None;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        TopMost = true;
        AutoScaleMode = AutoScaleMode.Dpi;
    }

    protected virtual bool ClickThrough => false;

    protected override bool ShowWithoutActivation => true;

    protected override CreateParams CreateParams
    {
        get
        {
            var parameters = base.CreateParams;
            parameters.ExStyle |= NativeMethods.WsExNoActivate | NativeMethods.WsExToolWindow | NativeMethods.WsExTopmost;
            if (ClickThrough) parameters.ExStyle |= NativeMethods.WsExTransparent | NativeMethods.WsExLayered;
            return parameters;
        }
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == NativeMethods.WmMouseActivate)
        {
            m.Result = NativeMethods.MaNoActivate;
            return;
        }
        base.WndProc(ref m);
    }

    public void ShowAt(Rectangle bounds)
    {
        if (Bounds != bounds) Bounds = bounds;
        if (!Visible) Show();
    }

    /// <summary>Removes and disposes the controls, so rebuilding a card doesn't leak window handles.</summary>
    protected static void Clear(Control parent)
    {
        var old = parent.Controls.Cast<Control>().ToList();
        parent.Controls.Clear();
        foreach (var control in old) control.Dispose();
    }
}

/// <summary>A clickable, non-focusable label, so clicking it doesn't move the focus out of the edited app.</summary>
internal sealed class ClickLabel : Label
{
    private readonly Color _normal;
    private readonly Color _hover;

    public ClickLabel(string text, Color background, Color foreground, Font? font = null)
    {
        SetStyle(ControlStyles.Selectable, false);
        Text = text;
        AutoSize = true;
        Padding = new Padding(8, 4, 8, 4);
        Margin = new Padding(0, 0, 6, 6);
        Cursor = Cursors.Hand;
        _normal = background;
        _hover = ControlPaint.Dark(background, 0.05f);
        BackColor = background;
        ForeColor = foreground;
        if (font is not null) Font = font;
        MouseEnter += (_, _) => BackColor = _hover;
        MouseLeave += (_, _) => BackColor = _normal;
    }
}
