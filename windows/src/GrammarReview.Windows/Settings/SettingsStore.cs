using System.IO;
using GrammarReview.Core.Settings;

namespace GrammarReview.Windows.Settings;

internal sealed class SettingsStore
{
    private readonly SettingsFile _file = new(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "Grammar Review", "settings.json"));

    public SettingsStore() => Settings = _file.Load();

    public AppSettings Settings { get; private set; }

    public event Action<AppSettings>? Changed;

    public void Update(Func<AppSettings, AppSettings> change)
    {
        var updated = change(Settings);
        if (updated == Settings) return;
        Settings = updated;
        try
        {
            _file.Save(updated);
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException)
        {
        }
        Changed?.Invoke(updated);
    }

    public void AddToDictionary(string word)
    {
        var trimmed = word.Trim();
        if (trimmed.Length == 0 || Settings.IsInPersonalDictionary(trimmed)) return;
        Update(settings => settings with { PersonalDictionary = [.. settings.PersonalDictionary, trimmed] });
    }
}
