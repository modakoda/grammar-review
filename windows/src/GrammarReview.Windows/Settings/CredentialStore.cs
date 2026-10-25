using System.Runtime.InteropServices;
using ComFileTime = System.Runtime.InteropServices.ComTypes.FILETIME;

namespace GrammarReview.Windows.Settings;

/// <summary>The Anthropic API key in Windows Credential Manager, with ANTHROPIC_API_KEY as a fallback.</summary>
internal static class CredentialStore
{
    public const string Target = "Grammar Review/anthropic-api-key";
    public const string EnvironmentVariable = "ANTHROPIC_API_KEY";

    private const uint GenericType = 1;
    private const uint PersistLocalMachine = 2;

    public static string? ApiKey() =>
        Saved() ?? (Environment.GetEnvironmentVariable(EnvironmentVariable)?.Trim() is { Length: > 0 } key ? key : null);

    public static bool HasSavedKey => Saved() is not null;

    public static string? Saved()
    {
        if (!CredRead(Target, GenericType, 0, out var pointer)) return null;
        try
        {
            var credential = Marshal.PtrToStructure<Credential>(pointer);
            if (credential.CredentialBlob == IntPtr.Zero || credential.CredentialBlobSize == 0) return null;
            var key = Marshal.PtrToStringUni(credential.CredentialBlob, (int)credential.CredentialBlobSize / 2).Trim();
            return key.Length == 0 ? null : key;
        }
        finally
        {
            CredFree(pointer);
        }
    }

    public static void Save(string? key)
    {
        var trimmed = key?.Trim() ?? "";
        if (trimmed.Length == 0)
        {
            CredDelete(Target, GenericType, 0);
            return;
        }
        var blob = Marshal.StringToCoTaskMemUni(trimmed);
        try
        {
            var credential = new Credential
            {
                Type = GenericType,
                TargetName = Target,
                Comment = "Grammar Review: Anthropic API key",
                CredentialBlobSize = (uint)(trimmed.Length * 2),
                CredentialBlob = blob,
                Persist = PersistLocalMachine,
                UserName = Environment.UserName,
            };
            if (!CredWrite(ref credential, 0)) throw new InvalidOperationException($"Credential Manager refused the key (error {Marshal.GetLastWin32Error()}).");
        }
        finally
        {
            Marshal.ZeroFreeCoTaskMemUnicode(blob);
        }
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct Credential
    {
        public uint Flags;
        public uint Type;
        public string TargetName;
        public string? Comment;
        public ComFileTime LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public string? TargetAlias;
        public string? UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(string target, uint type, uint flags, out IntPtr credential);

    [DllImport("advapi32.dll", EntryPoint = "CredWriteW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredWrite(ref Credential credential, uint flags);

    [DllImport("advapi32.dll", EntryPoint = "CredDeleteW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredDelete(string target, uint type, uint flags);

    [DllImport("advapi32.dll")]
    private static extern void CredFree(IntPtr buffer);
}
