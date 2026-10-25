namespace GrammarReview.Core.Harper;

public abstract record HarperLocation
{
    public sealed record Found(string Path) : HarperLocation;

    public sealed record Missing : HarperLocation;

    public sealed record Invalid(string Path) : HarperLocation;
}

/// <summary>Finds harper-ls: a chosen path, then PATH, then where installers usually put it.</summary>
public sealed class HarperLocator(IReadOnlyDictionary<string, string?>? environment = null, string? home = null, Func<string, bool>? isExecutable = null, bool? windows = null)
{
    private readonly bool _windows = windows ?? OperatingSystem.IsWindows();
    private readonly IReadOnlyDictionary<string, string?> _environment = environment ?? Environment.GetEnvironmentVariables()
        .Cast<System.Collections.DictionaryEntry>()
        .ToDictionary(entry => (string)entry.Key, entry => entry.Value as string, StringComparer.OrdinalIgnoreCase);
    private readonly string _home = home ?? Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
    private readonly Func<string, bool> _isExecutable = isExecutable ?? IsExecutableFile;

    public string ProgramName => _windows ? "harper-ls.exe" : "harper-ls";

    public IReadOnlyList<string> SearchDirectories()
    {
        var separator = _windows ? ';' : ':';
        var path = (_environment.GetValueOrDefault("PATH") ?? "").Split(separator, StringSplitOptions.RemoveEmptyEntries);
        IEnumerable<string> usual;
        if (_windows)
        {
            var local = _environment.GetValueOrDefault("LOCALAPPDATA") ?? Join(_home, "AppData", "Local");
            usual =
            [
                Join(_home, ".cargo", "bin"), Join(local, "Programs", "Harper"), Join(local, "Programs", "harper-ls"),
                Join(local, "Microsoft", "WinGet", "Links"), Join(_home, "scoop", "shims"),
            ];
        }
        else
        {
            usual = ["/opt/homebrew/bin", "/usr/local/bin", Join(_home, ".cargo", "bin"), Join(_home, ".local", "bin"), "/usr/bin"];
        }
        return path.Concat(usual).Distinct(_windows ? StringComparer.OrdinalIgnoreCase : StringComparer.Ordinal).ToList();
    }

    public HarperLocation Locate(string customPath)
    {
        var custom = customPath.Trim().Trim('"');
        if (custom.Length > 0)
        {
            var expanded = custom == "~" ? _home : custom.StartsWith("~/", StringComparison.Ordinal) ? Join(_home, custom[2..]) : custom;
            var candidates = new[] { expanded, Join(expanded, ProgramName) };
            return candidates.FirstOrDefault(_isExecutable) is { } found ? new HarperLocation.Found(found) : new HarperLocation.Invalid(expanded);
        }
        foreach (var directory in SearchDirectories())
        {
            var candidate = Join(directory, ProgramName);
            if (_isExecutable(candidate)) return new HarperLocation.Found(candidate);
        }
        return new HarperLocation.Missing();
    }

    private string Join(params string[] parts) => _windows ? string.Join('\\', parts.Select((p, i) => i == 0 ? p.TrimEnd('\\') : p.Trim('\\'))) : string.Join('/', parts.Select((p, i) => i == 0 ? p.TrimEnd('/') : p.Trim('/')));

    public static bool IsExecutableFile(string path)
    {
        if (!File.Exists(path)) return false;
        if (OperatingSystem.IsWindows()) return path.EndsWith(".exe", StringComparison.OrdinalIgnoreCase);
        return (File.GetUnixFileMode(path) & (UnixFileMode.UserExecute | UnixFileMode.GroupExecute | UnixFileMode.OtherExecute)) != 0;
    }
}
