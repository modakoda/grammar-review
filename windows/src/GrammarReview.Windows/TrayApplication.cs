using System.Net.Http;
using GrammarReview.Core;
using GrammarReview.Core.Engine;
using GrammarReview.Core.Harper;
using GrammarReview.Windows.Accessibility;
using GrammarReview.Windows.Overlay;
using GrammarReview.Windows.Session;
using GrammarReview.Windows.Settings;
using GrammarReview.Windows.Spelling;

namespace GrammarReview.Windows;

/// <summary>The app: a notification-area icon and menu, and a session for whichever text field has the focus.</summary>
internal sealed class TrayApplication : ApplicationContext
{
    private readonly SettingsStore _store = new();
    private readonly UiaThread _uia = new();
    private readonly HttpClient _http = new();
    private readonly UnderlineWindow _underlines = new();
    private readonly BadgeWindow _badge = new();
    private readonly CardWindow _card = new();
    private readonly PanelWindow _panel = new();
    private readonly GrammarEngine _engine;
    private readonly FocusTracker _tracker;
    private readonly NotifyIcon _icon;
    private readonly HotkeyWindow _hotkeys;
    private readonly ToolStripMenuItem _enabled = new("Check as You Type");
    private readonly ToolStripMenuItem _ai = new("AI Suggestions");
    private readonly ToolStripMenuItem _app = new("Disable in This App");
    private UiaTextField? _field;
    private FieldSession? _session;
    private SettingsForm? _settingsForm;

    public TrayApplication()
    {
        var ui = SynchronizationContext.Current ?? new WindowsFormsSynchronizationContext();
        _engine = new GrammarEngine(
            new WindowsSpellChecker(),
            new ClaudeProofreader(new ClaudeClient(_http)),
            CredentialStore.ApiKey,
            new HarperChecker(HarperClient.Shared));
        _tracker = new FocusTracker(_uia, ui);
        _tracker.FocusChanged += Follow;
        _badge.Click += (_, _) => _session?.TogglePanel();
        _store.Changed += _ => Follow(_field);
        _hotkeys = new HotkeyWindow(() => _session?.TogglePanel());

        _icon = new NotifyIcon
        {
            Icon = AppIcon.Create(SystemInformation.SmallIconSize.Width * 2),
            Text = "Grammar Review",
            ContextMenuStrip = Menu(),
            Visible = true,
        };
        _icon.DoubleClick += (_, _) => ShowSettings();
        _tracker.Start();

        if (CredentialStore.ApiKey() is null)
        {
            _icon.ShowBalloonTip(8000, "Grammar Review is running",
                "It checks spelling in any app. Add an Anthropic API key in Settings for grammar, clarity and style suggestions.", ToolTipIcon.Info);
        }
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _session?.Dispose();
            _tracker.Dispose();
            _hotkeys.Dispose();
            _icon.Visible = false;
            _icon.Dispose();
            foreach (var window in new Form[] { _underlines, _badge, _card, _panel }) window.Dispose();
            _settingsForm?.Dispose();
            _http.Dispose();
            _uia.Dispose();
            HarperClient.Shared.Dispose();
        }
        base.Dispose(disposing);
    }

    private void Follow(UiaTextField? field)
    {
        _session?.Dispose();
        _session = null;
        _field = field;
        var settings = _store.Settings;
        if (field is null || !settings.IsEnabled || !settings.AllowsApp(field.ProcessName)) return;
        _session = new FieldSession(field, new FieldServices(_engine, _uia, _store, _underlines, _badge, _card, _panel));
        _session.Start();
    }

    private ContextMenuStrip Menu()
    {
        var menu = new ContextMenuStrip();
        _enabled.Click += (_, _) => _store.Update(s => s with { IsEnabled = !s.IsEnabled });
        _ai.Click += (_, _) => _store.Update(s => s with { AIEnabled = !s.AIEnabled });
        _app.Click += (_, _) => ToggleCurrentApp();
        var suggestions = new ToolStripMenuItem("Show Suggestions", null, (_, _) => _session?.TogglePanel()) { ShortcutKeyDisplayString = "Ctrl+Alt+G" };
        menu.Items.AddRange(
        [
            _enabled, _ai, _app, suggestions, new ToolStripSeparator(),
            new ToolStripMenuItem("Settings…", null, (_, _) => ShowSettings()),
            new ToolStripMenuItem("Quit Grammar Review", null, (_, _) => ExitThread()),
        ]);
        menu.Opening += (_, _) =>
        {
            var settings = _store.Settings;
            _enabled.Checked = settings.IsEnabled;
            _ai.Checked = settings.AIEnabled;
            var app = _field?.ProcessName;
            _app.Visible = !string.IsNullOrEmpty(app);
            _app.Text = app is null ? "" : settings.AllowsApp(app) ? $"Disable in {app}" : $"Enable in {app}";
            suggestions.Enabled = _session is not null;
        };
        return menu;
    }

    private void ToggleCurrentApp()
    {
        if (_field?.ProcessName is not { Length: > 0 } app) return;
        _store.Update(settings =>
        {
            var apps = new HashSet<string>(settings.DisabledApps, StringComparer.OrdinalIgnoreCase);
            if (!apps.Remove(app)) apps.Add(app);
            return settings with { DisabledApps = apps };
        });
    }

    private void ShowSettings()
    {
        if (_settingsForm is { IsDisposed: false })
        {
            _settingsForm.Activate();
            return;
        }
        _settingsForm = new SettingsForm(_store, new ClaudeClient(_http));
        _settingsForm.Show();
        _settingsForm.Activate();
    }
}
