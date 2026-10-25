using System.Text;
using System.Text.Json.Nodes;
using GrammarReview.Core.Text;

namespace GrammarReview.Core.Harper;

/// <summary>Splits a byte stream into Language Server Protocol messages ("Content-Length" framing).</summary>
public sealed class LspFrameDecoder
{
    private static readonly byte[] Separator = "\r\n\r\n"u8.ToArray();
    private readonly List<byte> _buffer = [];

    public IReadOnlyList<byte[]> Append(ReadOnlySpan<byte> data)
    {
        _buffer.AddRange(data.ToArray());
        var messages = new List<byte[]>();
        while (IndexOfSeparator() is var headerEnd && headerEnd >= 0)
        {
            var header = Encoding.ASCII.GetString(_buffer.GetRange(0, headerEnd).ToArray());
            var bodyStart = headerEnd + Separator.Length;
            if (ContentLength(header) is not { } length)
            {
                _buffer.RemoveRange(0, bodyStart);
                continue;
            }
            if (_buffer.Count - bodyStart < length) break;
            messages.Add(_buffer.GetRange(bodyStart, length).ToArray());
            _buffer.RemoveRange(0, bodyStart + length);
        }
        return messages;
    }

    public static int? ContentLength(string header)
    {
        foreach (var line in header.Split("\r\n"))
        {
            var colon = line.IndexOf(':');
            if (colon < 0 || !line[..colon].Trim().Equals("Content-Length", StringComparison.OrdinalIgnoreCase)) continue;
            return int.TryParse(line[(colon + 1)..].Trim(), out var length) && length >= 0 ? length : null;
        }
        return null;
    }

    public static byte[] Frame(string json)
    {
        var body = Encoding.UTF8.GetBytes(json);
        return [.. Encoding.ASCII.GetBytes($"Content-Length: {body.Length}\r\n\r\n"), .. body];
    }

    private int IndexOfSeparator()
    {
        for (var i = 0; i + Separator.Length <= _buffer.Count; i++)
        {
            if (_buffer[i] == Separator[0] && _buffer[i + 1] == Separator[1] && _buffer[i + 2] == Separator[2] && _buffer[i + 3] == Separator[3]) return i;
        }
        return -1;
    }
}

public readonly record struct LspPosition(int Line, int Character)
{
    public JsonObject Json() => new() { ["line"] = Line, ["character"] = Character };

    public static LspPosition? From(JsonNode? node) =>
        node?["line"] is { } line && node["character"] is { } character ? new LspPosition(line.GetValue<int>(), character.GetValue<int>()) : null;
}

public readonly record struct LspRange(LspPosition Start, LspPosition End)
{
    public JsonObject Json() => new() { ["start"] = Start.Json(), ["end"] = End.Json() };

    public static LspRange? From(JsonNode? node) =>
        LspPosition.From(node?["start"]) is { } start && LspPosition.From(node?["end"]) is { } end ? new LspRange(start, end) : null;
}

/// <summary>Converts LSP line/character positions (UTF-16) into offsets in the whole text.</summary>
public sealed class LspLineIndex
{
    private readonly List<int> _starts = [0];
    private readonly List<int> _ends = [];

    public LspLineIndex(string text)
    {
        for (var index = 0; index < text.Length; index++)
        {
            if (text[index] == '\n')
            {
                _ends.Add(index);
                _starts.Add(index + 1);
            }
            else if (text[index] == '\r')
            {
                _ends.Add(index);
                if (index + 1 < text.Length && text[index + 1] == '\n') index++;
                _starts.Add(index + 1);
            }
        }
        _ends.Add(text.Length);
    }

    public int? Offset(LspPosition position)
    {
        if (position.Line < 0 || position.Character < 0 || position.Line >= _starts.Count) return null;
        return Math.Min(_starts[position.Line] + position.Character, _ends[position.Line]);
    }

    public TextSpan? Span(LspRange range) =>
        Offset(range.Start) is { } start && Offset(range.End) is { } end && end >= start ? new TextSpan(start, end - start) : null;
}

public sealed record LspDiagnostic(LspRange Range, string Message, string? Code)
{
    public JsonObject Json()
    {
        var json = new JsonObject { ["range"] = Range.Json(), ["message"] = Message };
        if (Code is not null) json["code"] = Code;
        return json;
    }

    public static IReadOnlyList<LspDiagnostic> ListFrom(JsonNode? diagnostics)
    {
        var list = new List<LspDiagnostic>();
        foreach (var node in diagnostics as JsonArray ?? [])
        {
            if (LspRange.From(node?["range"]) is not { } range || node?["message"]?.GetValue<string>() is not { } message) continue;
            list.Add(new LspDiagnostic(range, message, node["code"]?.ToString()));
        }
        return list;
    }
}

public sealed record LspTextEdit(LspRange Range, string NewText);

public sealed record LspCodeAction(string Title, IReadOnlyDictionary<string, IReadOnlyList<LspTextEdit>> Edits, string? LintKind = null, string? LintMessage = null)
{
    public const string IgnoreCommand = "HarperIgnoreLint";

    public bool IsIgnoreCommand => LintKind is not null || LintMessage is not null;

    public static IReadOnlyList<LspCodeAction> ListFrom(JsonNode? result)
    {
        var actions = new List<LspCodeAction>();
        foreach (var node in result as JsonArray ?? [])
        {
            if (node?["title"]?.GetValue<string>() is not { } title) continue;
            var edits = new Dictionary<string, IReadOnlyList<LspTextEdit>>();
            if (node["edit"]?["changes"] is JsonObject changes)
            {
                foreach (var (uri, list) in changes)
                {
                    edits[uri] = (list as JsonArray ?? [])
                        .Select(edit => LspRange.From(edit?["range"]) is { } range && edit?["newText"]?.GetValue<string>() is { } text ? new LspTextEdit(range, text) : null)
                        .OfType<LspTextEdit>()
                        .ToList();
                }
            }
            string? kind = null;
            string? message = null;
            if (node["command"] is JsonValue command && command.TryGetValue<string>(out var name) && name == IgnoreCommand)
            {
                var lint = (node["arguments"] as JsonArray ?? []).OfType<JsonObject>().FirstOrDefault();
                kind = lint?["lint_kind"]?.GetValue<string>();
                message = lint?["message"]?.GetValue<string>();
            }
            actions.Add(new LspCodeAction(title, edits, kind, message));
        }
        return actions;
    }

    /// <summary>Harper lists each lint's fixes before its ignore command, so a lint's fixes are the ones just before its own.</summary>
    public static IReadOnlyList<LspCodeAction> For(LspDiagnostic diagnostic, IReadOnlyList<LspCodeAction> actions)
    {
        var group = new List<LspCodeAction>();
        foreach (var action in actions)
        {
            group.Add(action);
            if (!action.IsIgnoreCommand) continue;
            if (action.LintMessage == diagnostic.Message) return group;
            group = [];
        }
        return actions;
    }
}

public static class LspMessage
{
    public static JsonObject Request(int id, string method, JsonNode parameters) =>
        new() { ["jsonrpc"] = "2.0", ["id"] = id, ["method"] = method, ["params"] = parameters };

    public static JsonObject Notification(string method, JsonNode parameters) =>
        new() { ["jsonrpc"] = "2.0", ["method"] = method, ["params"] = parameters };

    public static JsonObject Response(JsonNode? id, JsonNode? result) =>
        new() { ["jsonrpc"] = "2.0", ["id"] = id?.DeepClone(), ["result"] = result };

    public static JsonObject Document(string uri) => new() { ["uri"] = uri };
}
