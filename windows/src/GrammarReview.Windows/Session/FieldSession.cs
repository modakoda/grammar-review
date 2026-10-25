using GrammarReview.Core.Engine;
using GrammarReview.Core.Issues;
using GrammarReview.Core.Text;
using GrammarReview.Windows.Accessibility;
using GrammarReview.Windows.Native;
using GrammarReview.Windows.Overlay;
using GrammarReview.Windows.Settings;

namespace GrammarReview.Windows.Session;

internal sealed record FieldServices(
    GrammarEngine Engine,
    UiaThread Uia,
    SettingsStore Store,
    UnderlineWindow Underlines,
    BadgeWindow Badge,
    CardWindow Card,
    PanelWindow Panel);

/// <summary>
/// Checks the focused field: follows its text, streams check results in, draws the underlines and badge,
/// shows the card on hover, and applies fixes. Lives on the UI thread; UI Automation runs on the UIA thread.
/// </summary>
internal sealed class FieldSession : IDisposable
{
    public static readonly TimeSpan Debounce = TimeSpan.FromMilliseconds(250);
    public static readonly TimeSpan TypingSettle = TimeSpan.FromMilliseconds(1200);
    public static readonly TimeSpan HoverDelay = TimeSpan.FromMilliseconds(250);
    public static readonly TimeSpan HideDelay = TimeSpan.FromMilliseconds(400);
    public const int MaxDrawnIssues = 50;

    private readonly UiaTextField _field;
    private readonly FieldServices _services;
    private readonly System.Windows.Forms.Timer _poll = new() { Interval = 300 };
    private readonly System.Windows.Forms.Timer _geometry = new() { Interval = 150 };
    private readonly System.Windows.Forms.Timer _hover = new() { Interval = 60 };
    private readonly HashSet<string> _ignored = [];
    private readonly CardActions _actions;

    private string _text = "";
    private IReadOnlyList<TextIssue> _issues = [];
    private IReadOnlyList<(TextIssue Issue, IReadOnlyList<Rectangle> Rects)> _placed = [];
    private Rectangle? _bounds;
    private int? _caret;
    private AIStatus _status = AIStatus.Completed;
    private bool _checking;
    private bool _focused = true;
    private bool _reading;
    private bool _measuring;
    private bool _disposed;
    private DateTime _lastEdit = DateTime.MinValue;
    private (Guid Id, DateTime Since)? _hovered;
    private DateTime? _leftCardAt;
    private CancellationTokenSource? _debounce;
    private CancellationTokenSource? _check;

    public FieldSession(UiaTextField field, FieldServices services)
    {
        _field = field;
        _services = services;
        _actions = new CardActions((issue, replacement) => _ = AcceptAsync(issue, replacement), Ignore, AddToDictionary);
        _poll.Tick += async (_, _) => await PollAsync();
        _geometry.Tick += async (_, _) => await MeasureAsync();
        _hover.Tick += (_, _) => TrackHover();
    }

    public string ProcessName => _field.ProcessName;

    public async void Start()
    {
        _poll.Start();
        _geometry.Start();
        _hover.Start();
        await PollAsync();
    }

    public void TogglePanel()
    {
        if (_services.Panel.Visible)
        {
            _services.Panel.Hide();
            return;
        }
        ShowPanel();
    }

    public void Dispose()
    {
        if (_disposed) return;
        _disposed = true;
        _poll.Dispose();
        _geometry.Dispose();
        _hover.Dispose();
        _debounce?.Cancel();
        _check?.Cancel();
        HideOverlays();
    }

    private async Task PollAsync()
    {
        if (_reading || _disposed) return;
        _reading = true;
        try
        {
            var (text, focused) = await _services.Uia.RunAsync(() => (_field.ReadText(), _field.IsFocused()));
            if (_disposed) return;
            _focused = focused;
            if (text is null || !focused)
            {
                HideOverlays();
                return;
            }
            if (text != _text) TextChanged(text);
        }
        catch (OperationCanceledException)
        {
        }
        finally
        {
            _reading = false;
        }
    }

    private void TextChanged(string text)
    {
        _issues = IssueRebaser.Rebase(_issues, _text, text);
        _text = text;
        _lastEdit = DateTime.UtcNow;
        if (_services.Card.Issue is { } shown && _issues.All(i => i.Id != shown.Id)) _services.Card.Dismiss();
        ScheduleCheck();
    }

    private async void ScheduleCheck()
    {
        _debounce?.Cancel();
        var debounce = _debounce = new CancellationTokenSource();
        _checking = _text.Trim().Length > 0;
        Render();
        try
        {
            await Task.Delay(Debounce, debounce.Token);
        }
        catch (OperationCanceledException)
        {
            return;
        }
        await CheckAsync();
    }

    private async Task CheckAsync()
    {
        _check?.Cancel();
        var check = _check = new CancellationTokenSource();
        if (_text.Trim().Length == 0)
        {
            _issues = [];
            _checking = false;
            Render();
            return;
        }
        var request = new CheckRequest(_text, _services.Store.Settings, NativeMethods.ForegroundKeyboardCulture());
        try
        {
            await foreach (var result in _services.Engine.CheckAsync(request, check.Token))
            {
                if (check.IsCancellationRequested || _disposed) return;
                Handle(result);
            }
        }
        catch (OperationCanceledException)
        {
        }
    }

    private void Handle(CheckResult result)
    {
        var fresh = result.Text == _text ? result.Issues : IssueRebaser.Rebase(result.Issues, result.Text, _text);
        if (!result.IsFinal)
        {
            var carried = _issues.Where(old => old.Source == IssueSource.AI && !fresh.Any(f => f.Range.Overlaps(old.Range)));
            fresh = [.. fresh.Concat(carried).OrderBy(i => i.Range.Start)];
        }
        _issues = fresh.Where(i => !_ignored.Contains(i.Fingerprint)).ToList();
        _status = result.Status;
        if (result.IsFinal && result.Text == _text) _checking = false;
        _ = MeasureAsync();
        if (_services.Panel.Visible) ShowPanel();
    }

    private async Task MeasureAsync()
    {
        if (_measuring || _disposed) return;
        _measuring = true;
        try
        {
            var text = _text;
            var issues = _issues.Take(MaxDrawnIssues).ToList();
            var (bounds, rects, caret) = await _services.Uia.RunAsync(() =>
                (_field.Bounds(), issues.Select(issue => _field.Rects(issue.Range, text)).ToList(), _field.Caret(text)));
            if (_disposed || text != _text) return;
            _bounds = bounds;
            _caret = caret;
            _placed = issues.Zip(rects, (issue, lines) => (issue, lines)).ToList();
            Render();
        }
        catch (OperationCanceledException)
        {
        }
        finally
        {
            _measuring = false;
        }
    }

    private IReadOnlyList<TextIssue> Visible()
    {
        if (DateTime.UtcNow - _lastEdit > TypingSettle || _caret is not { } caret) return _issues;
        return _issues.Where(i => !(i.Source == IssueSource.Local && caret >= i.Range.Start && caret <= i.Range.End)).ToList();
    }

    private void Render()
    {
        if (_disposed) return;
        if (_bounds is not { } bounds || !_focused)
        {
            HideOverlays();
            return;
        }
        var visible = Visible().Select(i => i.Id).ToHashSet();
        _services.Underlines.Draw(bounds, _placed
            .Where(p => visible.Contains(p.Issue.Id))
            .SelectMany(p => p.Rects.Select(rect => (rect, Palette.For(p.Issue.Category))))
            .ToList());

        if (!_services.Store.Settings.ShowBadge)
        {
            _services.Badge.Hide();
            return;
        }
        var count = visible.Count;
        var (label, color, tooltip) = _status.State switch
        {
            _ when _checking => ("…", Palette.Muted, "Checking…"),
            AIState.Failed or AIState.MissingApiKey => (count > 0 ? $"{count}" : "!", Palette.Warning, _status.Message ?? "AI suggestions are unavailable"),
            _ when count == 0 => ("✓", Palette.Good, "No suggestions"),
            _ => ($"{Math.Min(count, 99)}", Palette.For(_issues.Where(i => visible.Contains(i.Id)).Min(i => i.Category.Severity())), $"{count} suggestions"),
        };
        _services.Badge.Place(bounds, label, color, tooltip);
    }

    private void TrackHover()
    {
        if (_disposed) return;
        var point = Cursor.Position;
        var card = _services.Card;
        if (card.Visible && card.Bounds.Contains(point))
        {
            _leftCardAt = null;
            return;
        }
        var visible = Visible().Select(i => i.Id).ToHashSet();
        var hit = _placed.FirstOrDefault(p => visible.Contains(p.Issue.Id) && p.Rects.Any(r => Rectangle.Inflate(r, 0, 3).Contains(point)));
        var now = DateTime.UtcNow;
        if (hit.Issue is { } issue)
        {
            _leftCardAt = null;
            if (_hovered?.Id != issue.Id)
            {
                _hovered = (issue.Id, now);
            }
            else if (now - _hovered.Value.Since >= HoverDelay && card.Issue?.Id != issue.Id)
            {
                card.Show(issue, hit.Rects[0], _actions);
            }
            return;
        }
        _hovered = null;
        if (!card.Visible) return;
        _leftCardAt ??= now;
        if (now - _leftCardAt >= HideDelay) card.Dismiss();
    }

    private async Task<bool> AcceptAsync(TextIssue issue, string replacement)
    {
        _services.Card.Dismiss();
        var current = _issues.FirstOrDefault(i => i.Id == issue.Id) ?? issue;
        if (TextUnits.Substring(_text, current.Range) != current.OriginalText)
        {
            NativeMethods.MessageBeep(0);
            return false;
        }
        var text = _text;
        bool replaced;
        try
        {
            var typed = !replacement.Contains('\n') && !replacement.Contains('\r')
                && await _services.Uia.RunAsync(() => _field.Select(current.Range, text, current.OriginalText))
                && NativeMethods.TypeText(replacement);
            replaced = typed || await _services.Uia.RunAsync(() =>
                _field.SetValue(string.Concat(text.AsSpan(0, current.Range.Start), replacement, text.AsSpan(current.Range.End))));
        }
        catch (OperationCanceledException)
        {
            return false;
        }
        if (!replaced)
        {
            NativeMethods.MessageBeep(0);
            return false;
        }
        _issues = _issues.Where(i => i.Id != current.Id).ToList();
        Render();
        await Task.Delay(120);
        await PollAsync();
        return true;
    }

    private async void FixAll()
    {
        _services.Panel.Hide();
        var fixes = _issues.Where(i => i.Category.Severity() == IssueSeverity.Correctness && i.Replacements.Count > 0)
            .OrderByDescending(i => i.Range.Start)
            .Select(i => i.Id)
            .ToList();
        foreach (var id in fixes)
        {
            if (_disposed) return;
            if (_issues.FirstOrDefault(i => i.Id == id) is not { } issue) continue;
            await AcceptAsync(issue, issue.Replacements[0]);
        }
    }

    private void Ignore(TextIssue issue)
    {
        _ignored.Add(issue.Fingerprint);
        _issues = _issues.Where(i => i.Id != issue.Id).ToList();
        _services.Card.Dismiss();
        Render();
        if (_services.Panel.Visible) ShowPanel();
    }

    private void AddToDictionary(TextIssue issue)
    {
        var word = issue.OriginalText.Trim();
        _services.Store.AddToDictionary(word);
        _services.Engine.Learn(word);
        _issues = _issues.Where(i => !(i.Category == IssueCategory.Spelling && string.Equals(i.OriginalText.Trim(), word, StringComparison.OrdinalIgnoreCase))).ToList();
        _services.Card.Dismiss();
        Render();
    }

    private void ShowPanel()
    {
        if (_bounds is not { } bounds) return;
        var status = _status.State is AIState.Failed or AIState.MissingApiKey or AIState.TextTooLong
            ? _status.Message ?? (_status.State == AIState.TextTooLong ? "This text is too long for AI suggestions; spelling is still checked." : null)
            : null;
        var anchor = _services.Badge.Visible ? _services.Badge.Bounds : bounds;
        _services.Panel.Show(Visible(), status, anchor, _actions, FixAll, () => _services.Panel.Hide());
    }

    private void HideOverlays()
    {
        _services.Underlines.Hide();
        _services.Badge.Hide();
        _services.Card.Dismiss();
        _services.Panel.Hide();
    }
}
