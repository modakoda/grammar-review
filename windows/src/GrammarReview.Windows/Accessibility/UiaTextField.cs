using System.Runtime.InteropServices;
using System.Windows.Automation;
using System.Windows.Automation.Text;
using GrammarReview.Core.Text;

namespace GrammarReview.Windows.Accessibility;

/// <summary>An editable text field in another app. Call it only on the <see cref="UiaThread"/>.</summary>
internal sealed class UiaTextField(AutomationElement element, TextPattern? text, ValuePattern? value, int processId, string processName)
{
    public const int MaxLength = 20_000;

    private enum Counting
    {
        CodeUnits,
        LineBreaksAsOne,
        CharactersAsOne,
        Both,
    }

    private Counting? _counting;

    public int ProcessId { get; } = processId;
    public string ProcessName { get; } = processName;
    public bool CanReplace => text is not null || value is { Current.IsReadOnly: false };

    public string? ReadText() => Guard(() =>
    {
        var read = text?.DocumentRange.GetText(MaxLength + 1) ?? value?.Current.Value;
        return read is null || read.Length > MaxLength ? null : read;
    });

    public Rectangle? Bounds() => Guard<Rectangle?>(() => ToRectangle(element.Current.BoundingRectangle));

    public bool IsFocused() => Guard(() => element.Current.HasKeyboardFocus);

    /// <summary>The screen rectangles of each line of <paramref name="span"/>, empty when the app can't say.</summary>
    public IReadOnlyList<Rectangle> Rects(TextSpan span, string current) => Guard(() =>
    {
        if (RangeFor(span, current) is not { } range) return (IReadOnlyList<Rectangle>)[];
        return range.GetBoundingRectangles().Select(ToRectangle).OfType<Rectangle>().ToList();
    }) ?? [];

    public int? Caret(string current) => Guard<int?>(() =>
    {
        if (text?.GetSelection() is not [var selection, ..]) return null;
        var before = text.DocumentRange.Clone();
        before.MoveEndpointByRange(TextPatternRangeEndpoint.End, selection, TextPatternRangeEndpoint.Start);
        var prefix = before.GetText(MaxLength + 1);
        return current.StartsWith(prefix, StringComparison.Ordinal) ? prefix.Length : null;
    });

    /// <summary>Selects the words to replace, checking that they still read <paramref name="original"/>.</summary>
    public bool Select(TextSpan span, string current, string original) => Guard(() =>
    {
        if (RangeFor(span, current) is not { } range || range.GetText(-1) != original) return false;
        range.Select();
        return text?.GetSelection() is [var selected, ..] && selected.GetText(-1) == original;
    });

    public bool SetValue(string newText) => Guard(() =>
    {
        if (value is null || value.Current.IsReadOnly) return false;
        value.SetValue(newText);
        return true;
    });

    private TextPatternRange? RangeFor(TextSpan span, string current)
    {
        if (text is null || !span.Fits(current)) return null;
        var expected = current.Substring(span.Start, span.Length);
        var modes = _counting is { } known ? [known] : Enum.GetValues<Counting>();
        foreach (var mode in modes)
        {
            var range = Range(Units(current, span.Start, mode), Units(current, span.End, mode));
            if (range is null || range.GetText(-1) != expected) continue;
            _counting = mode;
            return range;
        }
        return null;
    }

    private TextPatternRange? Range(int start, int end)
    {
        var range = text!.DocumentRange.Clone();
        range.MoveEndpointByRange(TextPatternRangeEndpoint.End, range, TextPatternRangeEndpoint.Start);
        if (range.MoveEndpointByUnit(TextPatternRangeEndpoint.End, TextUnit.Character, end) < end) return null;
        if (range.MoveEndpointByUnit(TextPatternRangeEndpoint.Start, TextUnit.Character, start) < start) return null;
        return range;
    }

    private static int Units(string text, int offset, Counting mode)
    {
        var units = offset;
        for (var i = 0; i < offset - 1; i++)
        {
            var pair = mode switch
            {
                Counting.LineBreaksAsOne => text[i] == '\r' && text[i + 1] == '\n',
                Counting.CharactersAsOne => char.IsSurrogatePair(text[i], text[i + 1]),
                Counting.Both => (text[i] == '\r' && text[i + 1] == '\n') || char.IsSurrogatePair(text[i], text[i + 1]),
                _ => false,
            };
            if (!pair) continue;
            units--;
            i++;
        }
        return units;
    }

    private static Rectangle? ToRectangle(System.Windows.Rect rect)
    {
        if (rect.IsEmpty || double.IsInfinity(rect.Width) || rect.Width <= 0 || rect.Height <= 0) return null;
        return Rectangle.FromLTRB((int)Math.Floor(rect.Left), (int)Math.Floor(rect.Top), (int)Math.Ceiling(rect.Right), (int)Math.Ceiling(rect.Bottom));
    }

    private static T? Guard<T>(Func<T> read)
    {
        try
        {
            return read();
        }
        catch (Exception error) when (error is ElementNotAvailableException or COMException or InvalidOperationException or ArgumentException)
        {
            return default;
        }
    }
}
