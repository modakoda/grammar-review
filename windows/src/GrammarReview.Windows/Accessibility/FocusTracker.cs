using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Automation;

namespace GrammarReview.Windows.Accessibility;

/// <summary>Reports the editable, non-secure text field that has the keyboard focus, in any app but this one.</summary>
internal sealed class FocusTracker(UiaThread uia, SynchronizationContext ui) : IDisposable
{
    private readonly int _ownProcess = Environment.ProcessId;
    private readonly Dictionary<int, string> _processNames = [];
    private AutomationFocusChangedEventHandler? _handler;
    private int _sequence;

    public event Action<UiaTextField?>? FocusChanged;

    public void Start()
    {
        _handler = (sender, _) =>
        {
            if (sender is not AutomationElement element) return;
            var sequence = Interlocked.Increment(ref _sequence);
            uia.RunAsync(() => Inspect(element)).ContinueWith(task =>
            {
                var field = task.IsCompletedSuccessfully ? task.Result : null;
                ui.Post(_ =>
                {
                    if (sequence == Volatile.Read(ref _sequence)) FocusChanged?.Invoke(field);
                }, null);
            }, TaskScheduler.Default);
        };
        _ = uia.RunAsync(() =>
        {
            Automation.AddAutomationFocusChangedEventHandler(_handler);
            return true;
        });
        _ = uia.RunAsync(() => AutomationElement.FocusedElement).ContinueWith(task =>
        {
            if (task.IsCompletedSuccessfully && task.Result is { } element) _handler?.Invoke(element, null!);
        }, TaskScheduler.Default);
    }

    public void Dispose()
    {
        if (_handler is { } handler) _ = uia.RunAsync(() =>
        {
            Automation.RemoveAutomationFocusChangedEventHandler(handler);
            return true;
        });
        _handler = null;
    }

    private UiaTextField? Inspect(AutomationElement element)
    {
        try
        {
            var current = element.Current;
            if (current.ProcessId == _ownProcess || current.IsPassword || !current.IsEnabled) return null;
            var type = current.ControlType;
            if (type != ControlType.Edit && type != ControlType.Document && type != ControlType.Custom && type != ControlType.Group) return null;

            var text = element.TryGetCurrentPattern(TextPattern.Pattern, out var t) ? (TextPattern)t : null;
            var value = element.TryGetCurrentPattern(ValuePattern.Pattern, out var v) ? (ValuePattern)v : null;
            if (text is null && value is null) return null;
            if (value is { Current.IsReadOnly: true } && (text is null || type != ControlType.Edit)) return null;
            if (text is not null && text.DocumentRange.GetAttributeValue(TextPattern.IsReadOnlyAttribute) is true) return null;
            if (text is null && type != ControlType.Edit) return null;

            return new UiaTextField(element, text, value, current.ProcessId, ProcessName(current.ProcessId));
        }
        catch (Exception error) when (error is ElementNotAvailableException or COMException or InvalidOperationException or ArgumentException)
        {
            return null;
        }
    }

    private string ProcessName(int id)
    {
        if (_processNames.TryGetValue(id, out var name)) return name;
        try
        {
            using var process = Process.GetProcessById(id);
            name = process.ProcessName;
        }
        catch (ArgumentException)
        {
            name = "";
        }
        _processNames[id] = name;
        return name;
    }
}
