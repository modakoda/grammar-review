using System.Diagnostics;
using System.Text.Json;
using System.Text.Json.Nodes;

namespace GrammarReview.Core.Harper;

public interface IHarperLinter
{
    Task<IReadOnlyList<HarperLint>> LintAsync(string text, HarperConfiguration configuration, string executable, CancellationToken cancellation);
}

public enum HarperErrorKind
{
    LaunchFailed,
    Stopped,
    TimedOut,
    BackingOff,
    Server,
}

public sealed class HarperException(HarperErrorKind kind, string? detail = null) : Exception(detail ?? kind.ToString())
{
    public HarperErrorKind Kind { get; } = kind;
}

/// <summary>Talks to one long-running harper-ls over stdio. Lints run one at a time; a failure backs off for a minute.</summary>
public sealed class HarperClient : IHarperLinter, IDisposable
{
    public static HarperClient Shared { get; } = new();

    public static readonly TimeSpan StartTimeout = TimeSpan.FromSeconds(5);
    public static readonly TimeSpan ConfigurationTimeout = TimeSpan.FromSeconds(1);
    public static readonly TimeSpan LintTimeout = TimeSpan.FromSeconds(3);
    public static readonly TimeSpan RetryInterval = TimeSpan.FromSeconds(60);
    public const int MaxLints = 100;

    private readonly record struct Pending(string Kind, int Id = 0, string Uri = "");

    private sealed class Connection(Process process, Stream input, string executable, int generation)
    {
        public Process Process { get; } = process;
        public Stream Input { get; } = input;
        public string Executable { get; } = executable;
        public int Generation { get; } = generation;
    }

    private readonly SemaphoreSlim _turn = new(1, 1);
    private readonly Lock _gate = new();
    private readonly Dictionary<Pending, TaskCompletionSource<JsonNode>> _pending = [];
    private Connection? _connection;
    private HarperConfiguration? _configuration;
    private (string Executable, DateTime At)? _failure;
    private int _generation;
    private int _nextId = 1;
    private int _nextDocument = 1;

    public async Task<IReadOnlyList<HarperLint>> LintAsync(string text, HarperConfiguration configuration, string executable, CancellationToken cancellation)
    {
        await _turn.WaitAsync(cancellation).ConfigureAwait(false);
        try
        {
            cancellation.ThrowIfCancellationRequested();
            await PrepareAsync(executable, configuration, cancellation).ConfigureAwait(false);
            return await LintDocumentAsync(text, cancellation).ConfigureAwait(false);
        }
        catch (HarperException error) when (error.Kind is HarperErrorKind.LaunchFailed or HarperErrorKind.Stopped or HarperErrorKind.TimedOut)
        {
            Stop();
            lock (_gate) _failure = (executable, DateTime.UtcNow);
            throw;
        }
        finally
        {
            _turn.Release();
        }
    }

    public void Dispose()
    {
        Stop();
        _turn.Dispose();
    }

    private async Task PrepareAsync(string executable, HarperConfiguration configuration, CancellationToken cancellation)
    {
        if (_connection is { } running && running.Executable != executable) Stop();
        if (_connection is null)
        {
            lock (_gate)
            {
                if (_failure is { } failure && failure.Executable == executable && DateTime.UtcNow - failure.At < RetryInterval)
                {
                    throw new HarperException(HarperErrorKind.BackingOff);
                }
            }
            Launch(executable);
            _configuration = configuration;
            var id = Interlocked.Increment(ref _nextId);
            await WaitAsync(new Pending("response", id), StartTimeout, () => Send(LspMessage.Request(id, "initialize", InitializeParams())), cancellation).ConfigureAwait(false);
            await WaitForConfigurationAsync(() => Send(LspMessage.Notification("initialized", new JsonObject())), cancellation).ConfigureAwait(false);
            lock (_gate) _failure = null;
        }
        else if (_configuration != configuration)
        {
            _configuration = configuration;
            var notification = LspMessage.Notification("workspace/didChangeConfiguration", new JsonObject { ["settings"] = configuration.Settings() });
            await WaitForConfigurationAsync(() => Send(notification), cancellation).ConfigureAwait(false);
        }
    }

    private async Task WaitForConfigurationAsync(Action send, CancellationToken cancellation)
    {
        try
        {
            await WaitAsync(new Pending("configuration"), ConfigurationTimeout, send, cancellation).ConfigureAwait(false);
        }
        catch (HarperException error) when (error.Kind == HarperErrorKind.TimedOut)
        {
            // An older harper-ls may not ask; it lints with its defaults.
        }
    }

    private async Task<IReadOnlyList<HarperLint>> LintDocumentAsync(string text, CancellationToken cancellation)
    {
        var uri = $"untitled:grammar-review-{_nextDocument++}";
        try
        {
            var document = new JsonObject { ["uri"] = uri, ["languageId"] = "plaintext", ["version"] = 1, ["text"] = text };
            var published = await WaitAsync(new Pending("diagnostics", Uri: uri), LintTimeout,
                () => Send(LspMessage.Notification("textDocument/didOpen", new JsonObject { ["textDocument"] = document })), cancellation).ConfigureAwait(false);
            var diagnostics = LspDiagnostic.ListFrom(published["params"]?["diagnostics"]);
            var lines = new LspLineIndex(text);
            var lints = new List<HarperLint>();
            foreach (var diagnostic in diagnostics.Take(MaxLints))
            {
                var id = Interlocked.Increment(ref _nextId);
                var request = LspMessage.Request(id, "textDocument/codeAction", new JsonObject
                {
                    ["textDocument"] = LspMessage.Document(uri),
                    ["range"] = diagnostic.Range.Json(),
                    ["context"] = new JsonObject { ["diagnostics"] = new JsonArray(diagnostic.Json()) },
                });
                var response = await WaitAsync(new Pending("response", id), LintTimeout, () => Send(request), cancellation).ConfigureAwait(false);
                if (HarperLint.From(diagnostic, LspCodeAction.ListFrom(response["result"]), uri, lines, text) is { } lint) lints.Add(lint);
            }
            return lints;
        }
        finally
        {
            TrySend(LspMessage.Notification("textDocument/didClose", new JsonObject { ["textDocument"] = LspMessage.Document(uri) }));
        }
    }

    private void Launch(string executable)
    {
        var start = new ProcessStartInfo(executable, "--stdio")
        {
            UseShellExecute = false,
            RedirectStandardInput = true,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
        };
        Process process;
        try
        {
            process = Process.Start(start) ?? throw new HarperException(HarperErrorKind.LaunchFailed, "harper-ls didn't start");
        }
        catch (Exception error) when (error is System.ComponentModel.Win32Exception or InvalidOperationException or IOException)
        {
            throw new HarperException(HarperErrorKind.LaunchFailed, error.Message);
        }
        process.ErrorDataReceived += (_, _) => { };
        process.BeginErrorReadLine();
        var generation = Interlocked.Increment(ref _generation);
        var connection = new Connection(process, process.StandardInput.BaseStream, executable, generation);
        lock (_gate) _connection = connection;
        _ = Task.Run(() => ReadAsync(connection));
    }

    private async Task ReadAsync(Connection connection)
    {
        var decoder = new LspFrameDecoder();
        var buffer = new byte[16 * 1024];
        var output = connection.Process.StandardOutput.BaseStream;
        try
        {
            while (true)
            {
                var count = await output.ReadAsync(buffer).ConfigureAwait(false);
                if (count == 0) break;
                foreach (var message in decoder.Append(buffer.AsSpan(0, count))) Received(message, connection);
            }
        }
        catch (Exception error) when (error is IOException or ObjectDisposedException or InvalidOperationException)
        {
        }
        Ended(connection);
    }

    private void Received(byte[] data, Connection connection)
    {
        JsonNode? message;
        try
        {
            message = JsonNode.Parse(data);
        }
        catch (JsonException)
        {
            return;
        }
        if (message is null) return;
        var method = message["method"]?.GetValue<string>();
        var id = message["id"];
        if (method is not null && id is not null)
        {
            Answer(id, method, message, connection);
        }
        else if (method is null && id is JsonValue value && value.TryGetValue<int>(out var number))
        {
            if (message["error"]?["message"]?.GetValue<string>() is { } error)
            {
                Resolve(new Pending("response", number), exception: new HarperException(HarperErrorKind.Server, error));
            }
            else
            {
                Resolve(new Pending("response", number), message);
            }
        }
        else if (method == "textDocument/publishDiagnostics" && message["params"]?["uri"]?.GetValue<string>() is { } uri)
        {
            Resolve(new Pending("diagnostics", Uri: uri), message);
        }
    }

    private void Answer(JsonNode id, string method, JsonNode request, Connection connection)
    {
        if (method != "workspace/configuration")
        {
            TrySend(LspMessage.Response(id, null), connection);
            return;
        }
        var count = Math.Max(1, (request["params"]?["items"] as JsonArray)?.Count ?? 1);
        var settings = (_configuration ?? new HarperConfiguration(HarperDialect.American)).Settings();
        TrySend(LspMessage.Response(id, new JsonArray(Enumerable.Range(0, count).Select(_ => (JsonNode)settings.DeepClone()).ToArray())), connection);
        Resolve(new Pending("configuration"), new JsonObject());
    }

    private void Ended(Connection connection)
    {
        lock (_gate)
        {
            if (_connection != connection) return;
            _connection = null;
            _failure = (connection.Executable, DateTime.UtcNow);
        }
        _configuration = null;
        FailAll(new HarperException(HarperErrorKind.Stopped));
    }

    private void Stop()
    {
        Connection? connection;
        lock (_gate)
        {
            connection = _connection;
            _connection = null;
        }
        _configuration = null;
        if (connection is null) return;
        try
        {
            connection.Input.Dispose();
            if (!connection.Process.HasExited) connection.Process.Kill();
        }
        catch (Exception error) when (error is InvalidOperationException or IOException or System.ComponentModel.Win32Exception)
        {
        }
        connection.Process.Dispose();
        FailAll(new HarperException(HarperErrorKind.Stopped));
    }

    private void Send(JsonObject message)
    {
        var connection = _connection ?? throw new HarperException(HarperErrorKind.Stopped);
        if (!TrySend(message, connection)) throw new HarperException(HarperErrorKind.Stopped);
    }

    private void TrySend(JsonObject message)
    {
        if (_connection is { } connection) TrySend(message, connection);
    }

    private bool TrySend(JsonObject message, Connection connection)
    {
        var frame = LspFrameDecoder.Frame(message.ToJsonString());
        try
        {
            lock (connection)
            {
                connection.Input.Write(frame);
                connection.Input.Flush();
            }
            return true;
        }
        catch (Exception error) when (error is IOException or ObjectDisposedException)
        {
            return false;
        }
    }

    private async Task<JsonNode> WaitAsync(Pending key, TimeSpan timeout, Action send, CancellationToken cancellation)
    {
        var waiter = new TaskCompletionSource<JsonNode>(TaskCreationOptions.RunContinuationsAsynchronously);
        lock (_gate)
        {
            if (_pending.Remove(key, out var stale)) stale.TrySetException(new HarperException(HarperErrorKind.Stopped));
            _pending[key] = waiter;
        }
        try
        {
            send();
            return await waiter.Task.WaitAsync(timeout, cancellation).ConfigureAwait(false);
        }
        catch (TimeoutException)
        {
            throw new HarperException(HarperErrorKind.TimedOut);
        }
        finally
        {
            lock (_gate)
            {
                if (_pending.TryGetValue(key, out var current) && current == waiter) _pending.Remove(key);
            }
        }
    }

    private void Resolve(Pending key, JsonNode? result = null, Exception? exception = null)
    {
        TaskCompletionSource<JsonNode>? waiter;
        lock (_gate)
        {
            if (!_pending.Remove(key, out waiter)) return;
        }
        if (exception is not null) waiter.TrySetException(exception);
        else waiter.TrySetResult(result ?? new JsonObject());
    }

    private void FailAll(Exception exception)
    {
        List<TaskCompletionSource<JsonNode>> waiters;
        lock (_gate)
        {
            waiters = [.. _pending.Values];
            _pending.Clear();
        }
        foreach (var waiter in waiters) waiter.TrySetException(exception);
    }

    private static JsonObject InitializeParams() => new()
    {
        ["processId"] = Environment.ProcessId,
        ["rootUri"] = null,
        ["clientInfo"] = new JsonObject { ["name"] = "Grammar Review" },
        ["capabilities"] = new JsonObject
        {
            ["general"] = new JsonObject { ["positionEncodings"] = new JsonArray("utf-16") },
            ["workspace"] = new JsonObject { ["configuration"] = true },
            ["textDocument"] = new JsonObject
            {
                ["publishDiagnostics"] = new JsonObject(),
                ["codeAction"] = new JsonObject
                {
                    ["codeActionLiteralSupport"] = new JsonObject
                    {
                        ["codeActionKind"] = new JsonObject { ["valueSet"] = new JsonArray("quickfix") },
                    },
                },
            },
        },
    };
}
