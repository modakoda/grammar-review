using GrammarReview.Windows.Native;

namespace GrammarReview.Windows;

/// <summary>A message-only window that receives Ctrl+Alt+G from anywhere.</summary>
internal sealed class HotkeyWindow : NativeWindow, IDisposable
{
    private const int ShowSuggestions = 1;
    private static readonly IntPtr MessageOnly = new(-3);
    private readonly Action _showSuggestions;

    public HotkeyWindow(Action showSuggestions)
    {
        _showSuggestions = showSuggestions;
        CreateHandle(new CreateParams { Parent = MessageOnly });
        Registered = NativeMethods.RegisterHotKey(Handle, ShowSuggestions, NativeMethods.ModControl | NativeMethods.ModAlt | NativeMethods.ModNoRepeat, 'G');
    }

    public bool Registered { get; }

    public void Dispose()
    {
        if (Registered) NativeMethods.UnregisterHotKey(Handle, ShowSuggestions);
        DestroyHandle();
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == NativeMethods.WmHotkey && m.WParam == ShowSuggestions) _showSuggestions();
        base.WndProc(ref m);
    }
}
