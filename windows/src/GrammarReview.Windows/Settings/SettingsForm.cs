using System.Globalization;
using GrammarReview.Core;
using GrammarReview.Core.Harper;
using GrammarReview.Core.Settings;

namespace GrammarReview.Windows.Settings;

/// <summary>The Settings window: checking, the Anthropic key and model, Harper, apps and the dictionary.</summary>
internal sealed class SettingsForm : Form
{
    private static readonly string[] Languages =
    [
        "en-US", "en-GB", "en-AU", "en-CA", "lt-LT", "de-DE", "fr-FR", "es-ES", "it-IT", "pl-PL",
        "pt-BR", "pt-PT", "nl-NL", "sv-SE", "da-DK", "nb-NO", "fi-FI", "cs-CZ", "uk-UA",
    ];

    private readonly SettingsStore _store;
    private readonly ClaudeClient _claude;
    private readonly CheckBox _enabled = new() { Text = "Check spelling and grammar as you type", AutoSize = true };
    private readonly ComboBox _language = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 280 };
    private readonly CheckBox _showBadge = new() { Text = "Show the badge on the field", AutoSize = true };
    private readonly CheckBox _ai = new() { Text = "Use Claude for grammar, clarity and style", AutoSize = true };
    private readonly TextBox _key = new() { UseSystemPasswordChar = true, Width = 280, PlaceholderText = "sk-ant-…" };
    private readonly Label _keyStatus = new() { AutoSize = true, ForeColor = SystemColors.GrayText };
    private readonly ComboBox _model = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 280 };
    private readonly NumericUpDown _delay = new() { Minimum = 0.2m, Maximum = 5m, Increment = 0.1m, DecimalPlaces = 1, Width = 70 };
    private readonly CheckBox _harper = new() { Text = "Check English grammar offline with Harper", AutoSize = true };
    private readonly Label _harperStatus = new() { AutoSize = true, MaximumSize = new Size(440, 0), ForeColor = SystemColors.GrayText };
    private readonly TextBox _apps = new() { Multiline = true, ScrollBars = ScrollBars.Vertical, Width = 440, Height = 80 };
    private readonly TextBox _dictionary = new() { Multiline = true, ScrollBars = ScrollBars.Vertical, Width = 440, Height = 80 };
    private string _harperPath;

    public SettingsForm(SettingsStore store, ClaudeClient claude)
    {
        _store = store;
        _claude = claude;
        var settings = store.Settings;
        _harperPath = settings.HarperPath;

        Text = "Grammar Review Settings";
        FormBorderStyle = FormBorderStyle.FixedDialog;
        MaximizeBox = false;
        MinimizeBox = false;
        StartPosition = FormStartPosition.CenterScreen;
        AutoScaleMode = AutoScaleMode.Dpi;
        AutoSize = true;
        AutoSizeMode = AutoSizeMode.GrowAndShrink;
        Font = new Font("Segoe UI", 9f);
        Padding = new Padding(12);

        _language.Items.Add("Automatic (the keyboard layout's language)");
        foreach (var tag in Languages) _language.Items.Add($"{CultureInfo.GetCultureInfo(tag).DisplayName} — {tag}");
        _language.SelectedIndex = settings.Language is { } language && Array.IndexOf(Languages, language) is var index and >= 0 ? index + 1 : 0;
        foreach (var option in ModelOptions.All) _model.Items.Add(option.Name);
        _model.SelectedIndex = Math.Max(0, ModelOptions.All.ToList().FindIndex(o => o.Id == settings.Model));
        _enabled.Checked = settings.IsEnabled;
        _showBadge.Checked = settings.ShowBadge;
        _ai.Checked = settings.AIEnabled;
        _delay.Value = (decimal)Math.Clamp(settings.AIDelaySeconds, 0.2, 5);
        _harper.Checked = settings.HarperEnabled;
        _apps.Text = string.Join(Environment.NewLine, settings.DisabledApps.Order(StringComparer.OrdinalIgnoreCase));
        _dictionary.Text = string.Join(Environment.NewLine, settings.PersonalDictionary);
        ShowKeyStatus();

        var testKey = new Button { Text = "Test", AutoSize = true };
        testKey.Click += async (_, _) => await TestKeyAsync(testKey);
        var removeKey = new LinkLabel { Text = "Remove the saved key", AutoSize = true };
        removeKey.LinkClicked += (_, _) =>
        {
            CredentialStore.Save(null);
            ShowKeyStatus();
        };
        var getKey = Link("Get an API key in the Claude Console", "https://platform.claude.com/settings/keys");
        var chooseHarper = new Button { Text = "Choose harper-ls.exe…", AutoSize = true };
        chooseHarper.Click += (_, _) => ChooseHarper();
        var findHarper = new Button { Text = "Find Automatically", AutoSize = true };
        findHarper.Click += async (_, _) =>
        {
            _harperPath = "";
            await ShowHarperStatusAsync();
        };

        var layout = Column(
            Group("Checking", _enabled, Row(new Label { Text = "Language:", AutoSize = true, Margin = new Padding(0, 6, 6, 0) }, _language), _showBadge),
            Group("AI suggestions", _ai, Row(_key, testKey), _keyStatus, Row(removeKey, getKey),
                Row(new Label { Text = "Model:", AutoSize = true, Margin = new Padding(0, 6, 6, 0) }, _model),
                Row(new Label { Text = "Wait after typing (seconds):", AutoSize = true, Margin = new Padding(0, 6, 6, 0) }, _delay)),
            Group("Offline grammar", _harper, _harperStatus, Row(chooseHarper, findHarper),
                Link("Harper is a free, open-source grammar checker. Get harper-ls for Windows", "https://writewithharper.com/docs/integrations/language-server")),
            Group("Apps to leave alone (process names, one per line)", _apps),
            Group("Your dictionary (one word per line)", _dictionary),
            Buttons());
        layout.Location = new Point(Padding.Left, Padding.Top);
        Controls.Add(layout);
        Shown += async (_, _) => await ShowHarperStatusAsync();
    }

    private Control Buttons()
    {
        var save = new Button { Text = "Save", AutoSize = true, DialogResult = DialogResult.OK };
        save.Click += (_, _) =>
        {
            Save();
            Close();
        };
        var cancel = new Button { Text = "Cancel", AutoSize = true };
        cancel.Click += (_, _) => Close();
        AcceptButton = save;
        CancelButton = cancel;
        var row = Row(save, cancel);
        row.Anchor = AnchorStyles.Right;
        return row;
    }

    private void Save()
    {
        var key = _key.Text.Trim();
        if (key.Length > 0)
        {
            try
            {
                CredentialStore.Save(key);
            }
            catch (InvalidOperationException error)
            {
                MessageBox.Show(this, error.Message, "Grammar Review", MessageBoxButtons.OK, MessageBoxIcon.Warning);
            }
        }
        static IReadOnlyList<string> Lines(string text) =>
            text.Split(['\r', '\n'], StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).Distinct(StringComparer.OrdinalIgnoreCase).ToList();
        _store.Update(settings => settings with
        {
            IsEnabled = _enabled.Checked,
            Language = _language.SelectedIndex > 0 ? Languages[_language.SelectedIndex - 1] : null,
            ShowBadge = _showBadge.Checked,
            AIEnabled = _ai.Checked,
            Model = ModelOptions.All[Math.Max(0, _model.SelectedIndex)].Id,
            AIDelaySeconds = (double)_delay.Value,
            HarperEnabled = _harper.Checked,
            HarperPath = _harperPath,
            DisabledApps = new HashSet<string>(Lines(_apps.Text), StringComparer.OrdinalIgnoreCase),
            PersonalDictionary = Lines(_dictionary.Text),
        });
    }

    private async Task TestKeyAsync(Button button)
    {
        var key = _key.Text.Trim().Length > 0 ? _key.Text.Trim() : CredentialStore.ApiKey();
        if (key is null)
        {
            _keyStatus.Text = "Enter an API key first.";
            return;
        }
        button.Enabled = false;
        _keyStatus.Text = "Testing the key…";
        try
        {
            await _claude.ValidateKeyAsync(key, ModelOptions.All[Math.Max(0, _model.SelectedIndex)].Id, CancellationToken.None);
            _keyStatus.Text = $"The key works with {ModelOptions.All[Math.Max(0, _model.SelectedIndex)].Name}.";
        }
        catch (AIException error)
        {
            _keyStatus.Text = error.Kind == AIErrorKind.InvalidApiKey ? "Anthropic rejected this key. Check that you copied all of it." : error.UserMessage;
        }
        finally
        {
            button.Enabled = true;
        }
    }

    private void ShowKeyStatus()
    {
        _keyStatus.Text = CredentialStore.HasSavedKey ? "A key is saved in Windows Credential Manager."
            : CredentialStore.ApiKey() is not null ? $"Using the {CredentialStore.EnvironmentVariable} environment variable."
            : "No key saved. Only spelling (and Harper, if installed) is checked.";
    }

    private void ChooseHarper()
    {
        using var dialog = new OpenFileDialog { Filter = "harper-ls|harper-ls.exe|Programs|*.exe", Title = "Choose the harper-ls program" };
        if (dialog.ShowDialog(this) != DialogResult.OK) return;
        _harperPath = dialog.FileName;
        _ = ShowHarperStatusAsync();
    }

    private async Task ShowHarperStatusAsync()
    {
        _harperStatus.Text = "Looking for Harper…";
        var installation = await HarperProbe.InstallationAsync(_harperPath);
        _harperStatus.Text = installation switch
        {
            HarperInstallation.Found(var path, var version) => $"Harper {version} is ready: {path}",
            HarperInstallation.Unusable(var path, var reason) => $"{reason} ({path})",
            _ => "Harper isn't installed. Download harper-ls for Windows, or run: cargo install harper-ls",
        };
    }

    private static LinkLabel Link(string text, string url)
    {
        var link = new LinkLabel { Text = text, AutoSize = true, Margin = new Padding(0, 4, 0, 4) };
        link.LinkClicked += (_, _) => System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(url) { UseShellExecute = true });
        return link;
    }

    private static FlowLayoutPanel Row(params Control[] controls)
    {
        var row = new FlowLayoutPanel { AutoSize = true, FlowDirection = FlowDirection.LeftToRight, WrapContents = false, Margin = new Padding(0, 2, 0, 2) };
        row.Controls.AddRange(controls);
        return row;
    }

    private static FlowLayoutPanel Column(params Control[] controls)
    {
        var column = new FlowLayoutPanel { AutoSize = true, FlowDirection = FlowDirection.TopDown, WrapContents = false };
        column.Controls.AddRange(controls);
        return column;
    }

    private static FlowLayoutPanel Group(string title, params Control[] controls)
    {
        var heading = new Label { Text = title, AutoSize = true, Font = new Font("Segoe UI", 9f, FontStyle.Bold), Margin = new Padding(0, 0, 0, 4) };
        var body = Column(controls);
        body.Margin = new Padding(12, 0, 0, 0);
        var group = Column(heading, body);
        group.Margin = new Padding(0, 0, 0, 12);
        return group;
    }
}
