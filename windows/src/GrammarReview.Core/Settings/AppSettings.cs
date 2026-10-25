using System.Text.Json;
using System.Text.Json.Serialization;
using GrammarReview.Core.Issues;

namespace GrammarReview.Core.Settings;

public sealed record AppSettings
{
    public const string DefaultModel = "claude-haiku-5-5";

    public bool IsEnabled { get; init; } = true;
    public bool AIEnabled { get; init; } = true;
    public string Model { get; init; } = DefaultModel;
    public double AIDelaySeconds { get; init; } = 1.0;
    public int MaxAICharacters { get; init; } = 6000;

    /// <summary>A BCP 47 tag such as "en-GB", or null to follow the keyboard layout (and let the AI tell).</summary>
    public string? Language { get; init; }

    public bool HarperEnabled { get; init; } = true;
    public string HarperPath { get; init; } = "";
    public bool ShowBadge { get; init; } = true;
    public IReadOnlySet<IssueCategory> EnabledCategories { get; init; } = new HashSet<IssueCategory>(IssueCategories.All);
    public IReadOnlySet<string> DisabledApps { get; init; } = new HashSet<string>(DefaultDisabledApps, StringComparer.OrdinalIgnoreCase);
    public IReadOnlyList<string> PersonalDictionary { get; init; } = [];

    /// <summary>Process names: terminals, password managers and code editors.</summary>
    public static IReadOnlyList<string> DefaultDisabledApps { get; } =
    [
        "WindowsTerminal", "cmd", "powershell", "pwsh", "conhost", "wt",
        "KeePass", "KeePassXC", "1Password", "Bitwarden", "Dashlane",
        "Code", "devenv", "rider64", "idea64", "sublime_text", "notepad++",
    ];

    public bool AllowsApp(string? processName) => processName is null || !DisabledApps.Contains(processName);

    public bool IsInPersonalDictionary(string word) => PersonalDictionary.Any(entry => string.Equals(entry, word, StringComparison.OrdinalIgnoreCase));
}

public static class ModelOptions
{
    public static IReadOnlyList<(string Id, string Name, string Detail)> All { get; } =
    [
        ("claude-haiku-5-5", "Claude Haiku 5.5", "Fastest and cheapest. Recommended for as-you-type checks."),
        ("claude-sonnet-5-5", "Claude Sonnet 5.5", "Better style and clarity suggestions; slower."),
        ("claude-opus-5-5", "Claude Opus 5.5", "Highest quality; slowest and most expensive."),
    ];
}

/// <summary>Reads and writes the settings as JSON. A missing or unreadable file gives the defaults.</summary>
public sealed class SettingsFile(string path)
{
    private static readonly JsonSerializerOptions Options = new()
    {
        WriteIndented = true,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        Converters = { new JsonStringEnumConverter(JsonNamingPolicy.CamelCase) },
    };

    public string Path { get; } = path;

    public AppSettings Load()
    {
        try
        {
            if (!File.Exists(Path)) return new AppSettings();
            var loaded = JsonSerializer.Deserialize<StoredSettings>(File.ReadAllText(Path), Options);
            return loaded?.ToSettings() ?? new AppSettings();
        }
        catch (Exception error) when (error is JsonException or IOException or UnauthorizedAccessException or NotSupportedException)
        {
            return new AppSettings();
        }
    }

    public void Save(AppSettings settings)
    {
        Directory.CreateDirectory(System.IO.Path.GetDirectoryName(Path) ?? ".");
        var temporary = Path + ".tmp";
        File.WriteAllText(temporary, JsonSerializer.Serialize(StoredSettings.From(settings), Options));
        File.Move(temporary, Path, overwrite: true);
    }

    private sealed record StoredSettings
    {
        public bool? IsEnabled { get; init; }
        public bool? AIEnabled { get; init; }
        public string? Model { get; init; }
        public double? AIDelaySeconds { get; init; }
        public int? MaxAICharacters { get; init; }
        public string? Language { get; init; }
        public bool? HarperEnabled { get; init; }
        public string? HarperPath { get; init; }
        public bool? ShowBadge { get; init; }
        public List<IssueCategory>? EnabledCategories { get; init; }
        public List<string>? DisabledApps { get; init; }
        public List<string>? PersonalDictionary { get; init; }

        public static StoredSettings From(AppSettings settings) => new()
        {
            IsEnabled = settings.IsEnabled,
            AIEnabled = settings.AIEnabled,
            Model = settings.Model,
            AIDelaySeconds = settings.AIDelaySeconds,
            MaxAICharacters = settings.MaxAICharacters,
            Language = settings.Language,
            HarperEnabled = settings.HarperEnabled,
            HarperPath = settings.HarperPath,
            ShowBadge = settings.ShowBadge,
            EnabledCategories = settings.EnabledCategories.Order().ToList(),
            DisabledApps = settings.DisabledApps.Order(StringComparer.OrdinalIgnoreCase).ToList(),
            PersonalDictionary = settings.PersonalDictionary.ToList(),
        };

        public AppSettings ToSettings()
        {
            var defaults = new AppSettings();
            return new AppSettings
            {
                IsEnabled = IsEnabled ?? defaults.IsEnabled,
                AIEnabled = AIEnabled ?? defaults.AIEnabled,
                Model = string.IsNullOrWhiteSpace(Model) ? defaults.Model : Model,
                AIDelaySeconds = Math.Clamp(AIDelaySeconds ?? defaults.AIDelaySeconds, 0, 10),
                MaxAICharacters = MaxAICharacters is > 0 ? MaxAICharacters.Value : defaults.MaxAICharacters,
                Language = string.IsNullOrWhiteSpace(Language) ? null : Language.Trim(),
                HarperEnabled = HarperEnabled ?? defaults.HarperEnabled,
                HarperPath = HarperPath ?? defaults.HarperPath,
                ShowBadge = ShowBadge ?? defaults.ShowBadge,
                EnabledCategories = EnabledCategories is null ? defaults.EnabledCategories : new HashSet<IssueCategory>(EnabledCategories),
                DisabledApps = DisabledApps is null ? defaults.DisabledApps : new HashSet<string>(DisabledApps, StringComparer.OrdinalIgnoreCase),
                PersonalDictionary = PersonalDictionary ?? [],
            };
        }
    }
}
