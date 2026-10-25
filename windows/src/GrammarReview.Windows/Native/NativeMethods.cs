using System.Globalization;
using System.Runtime.InteropServices;

namespace GrammarReview.Windows.Native;

internal static class NativeMethods
{
    public const int WsExTransparent = 0x00000020;
    public const int WsExToolWindow = 0x00000080;
    public const int WsExTopmost = 0x00000008;
    public const int WsExLayered = 0x00080000;
    public const int WsExNoActivate = 0x08000000;
    public const int WmMouseActivate = 0x0021;
    public const int WmHotkey = 0x0312;
    public const int MaNoActivate = 3;
    public const uint ModAlt = 0x0001;
    public const uint ModControl = 0x0002;
    public const uint ModNoRepeat = 0x4000;

    private const uint InputKeyboard = 1;
    private const uint KeyEventUnicode = 0x0004;
    private const uint KeyEventKeyUp = 0x0002;

    [StructLayout(LayoutKind.Sequential)]
    private struct Input
    {
        public uint Type;
        public InputUnion Data;
    }

    [StructLayout(LayoutKind.Explicit)]
    private struct InputUnion
    {
        [FieldOffset(0)] public MouseInput Mouse;
        [FieldOffset(0)] public KeyboardInput Keyboard;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct MouseInput
    {
        public int X;
        public int Y;
        public uint MouseData;
        public uint Flags;
        public uint Time;
        public IntPtr ExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct KeyboardInput
    {
        public ushort VirtualKey;
        public ushort ScanCode;
        public uint Flags;
        public uint Time;
        public IntPtr ExtraInfo;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern uint SendInput(uint count, Input[] inputs, int size);

    [DllImport("user32.dll")]
    public static extern IntPtr GetForegroundWindow();

    [DllImport("user32.dll")]
    private static extern uint GetWindowThreadProcessId(IntPtr window, out uint processId);

    [DllImport("user32.dll")]
    private static extern IntPtr GetKeyboardLayout(uint threadId);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint key);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool UnregisterHotKey(IntPtr window, int id);

    [DllImport("user32.dll")]
    public static extern bool DestroyIcon(IntPtr icon);

    [DllImport("user32.dll")]
    public static extern bool MessageBeep(uint type);

    /// <summary>Types text into the focused control as Unicode keystrokes, replacing its selection. No clipboard involved.</summary>
    public static bool TypeText(string text)
    {
        if (text.Length == 0)
        {
            return SendKeys(0x2E);
        }
        var inputs = new List<Input>(text.Length * 2);
        foreach (var unit in text)
        {
            inputs.Add(Key(0, unit, KeyEventUnicode));
            inputs.Add(Key(0, unit, KeyEventUnicode | KeyEventKeyUp));
        }
        return SendInput((uint)inputs.Count, [.. inputs], Marshal.SizeOf<Input>()) == inputs.Count;
    }

    private static bool SendKeys(ushort virtualKey)
    {
        Input[] inputs = [Key(virtualKey, '\0', 0), Key(virtualKey, '\0', KeyEventKeyUp)];
        return SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<Input>()) == inputs.Length;
    }

    private static Input Key(ushort virtualKey, char unit, uint flags) => new()
    {
        Type = InputKeyboard,
        Data = new InputUnion { Keyboard = new KeyboardInput { VirtualKey = virtualKey, ScanCode = unit, Flags = flags } },
    };

    public static int ForegroundProcessId()
    {
        GetWindowThreadProcessId(GetForegroundWindow(), out var processId);
        return (int)processId;
    }

    /// <summary>The keyboard layout of the app in front, as a culture name such as "lt-LT".</summary>
    public static string? ForegroundKeyboardCulture()
    {
        var thread = GetWindowThreadProcessId(GetForegroundWindow(), out _);
        var language = (int)((long)GetKeyboardLayout(thread) & 0xFFFF);
        if (language == 0) return null;
        try
        {
            return CultureInfo.GetCultureInfo(language).Name;
        }
        catch (CultureNotFoundException)
        {
            return null;
        }
    }
}
