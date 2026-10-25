using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json.Nodes;

namespace GrammarReview.Core;

public sealed record ClaudeRequest(string Model, int MaxTokens, string System, string UserText, string Effort, JsonObject? OutputSchema);

public sealed record ClaudeResponse(string Text, string? StopReason);

public enum AIErrorKind
{
    MissingApiKey,
    InvalidApiKey,
    Busy,
    SpendCapReached,
    Offline,
    TimedOut,
    Refused,
    Truncated,
    InvalidResponse,
    Http,
}

public sealed class AIException(AIErrorKind kind, string? detail = null, int? status = null)
    : Exception(detail ?? kind.ToString())
{
    public AIErrorKind Kind { get; } = kind;
    public int? Status { get; } = status;
    public string? Detail { get; } = detail;

    public string UserMessage => Kind switch
    {
        AIErrorKind.MissingApiKey => "Add an Anthropic API key in Settings to get grammar and style suggestions.",
        AIErrorKind.InvalidApiKey => "Invalid API key",
        AIErrorKind.Busy => "Claude is busy — try again shortly",
        AIErrorKind.SpendCapReached => "Your Anthropic organization reached its monthly spend limit",
        AIErrorKind.Offline => "You're offline",
        AIErrorKind.TimedOut => "Claude took too long to respond",
        AIErrorKind.Refused => "Claude declined to check this text",
        AIErrorKind.Truncated => "Claude's answer was cut off",
        AIErrorKind.InvalidResponse => "Unexpected response from Claude",
        _ => Status switch
        {
            402 => "Billing problem — check your Anthropic account",
            403 => "Your API key can't use this model",
            404 => "This model isn't available. Choose another in Settings.",
            _ when !string.IsNullOrWhiteSpace(Detail) => $"Claude error: {Detail.Trim()[..Math.Min(160, Detail.Trim().Length)]}",
            _ => $"Claude request failed (HTTP {Status})",
        },
    };
}

/// <summary>The Anthropic Messages API, with structured output.</summary>
public sealed class ClaudeClient(HttpClient http, Uri? baseUrl = null, TimeSpan? retryDelay = null)
{
    public const string ApiVersion = "2026-10-21";
    public static readonly Uri DefaultBaseUrl = new("https://api.anthropic.com/");
    public static readonly TimeSpan Timeout = TimeSpan.FromSeconds(20);

    private readonly Uri _baseUrl = baseUrl ?? DefaultBaseUrl;
    private readonly TimeSpan _retryDelay = retryDelay ?? TimeSpan.FromSeconds(1);

    public static JsonObject Body(ClaudeRequest request)
    {
        var outputConfig = new JsonObject { ["effort"] = request.Effort };
        if (request.OutputSchema is { } schema)
        {
            outputConfig["format"] = new JsonObject { ["type"] = "json_schema", ["schema"] = schema.DeepClone() };
        }
        return new JsonObject
        {
            ["model"] = request.Model,
            ["max_tokens"] = request.MaxTokens,
            ["system"] = new JsonArray(new JsonObject
            {
                ["type"] = "text",
                ["text"] = request.System,
                ["cache_control"] = new JsonObject { ["type"] = "ephemeral" },
            }),
            ["messages"] = new JsonArray(new JsonObject { ["role"] = "user", ["content"] = request.UserText }),
            ["output_config"] = outputConfig,
        };
    }

    public async Task<ClaudeResponse> CreateMessageAsync(ClaudeRequest request, string apiKey, CancellationToken cancellation) =>
        Decode(await PostAsync("v1/messages", Body(request).ToJsonString(), apiKey, cancellation).ConfigureAwait(false));

    /// <summary>Checks a key without generating anything, by counting the tokens of "Hi".</summary>
    public async Task ValidateKeyAsync(string apiKey, string model, CancellationToken cancellation)
    {
        var body = new JsonObject
        {
            ["model"] = model,
            ["messages"] = new JsonArray(new JsonObject { ["role"] = "user", ["content"] = "Hi" }),
        };
        await PostAsync("v1/messages/count_tokens", body.ToJsonString(), apiKey, cancellation).ConfigureAwait(false);
    }

    private async Task<string> PostAsync(string path, string body, string apiKey, CancellationToken cancellation)
    {
        for (var attempt = 1; ; attempt++)
        {
            using var message = new HttpRequestMessage(HttpMethod.Post, new Uri(_baseUrl, path))
            {
                Content = new StringContent(body, Encoding.UTF8, "application/json"),
            };
            message.Headers.Add("x-api-key", apiKey);
            message.Headers.Add("anthropic-version", ApiVersion);
            message.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellation);
            timeout.CancelAfter(Timeout);
            HttpResponseMessage response;
            try
            {
                response = await http.SendAsync(message, timeout.Token).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (!cancellation.IsCancellationRequested)
            {
                throw new AIException(AIErrorKind.TimedOut);
            }
            catch (HttpRequestException error)
            {
                throw new AIException(error.HttpRequestError is HttpRequestError.NameResolutionError or HttpRequestError.ConnectionError
                    ? AIErrorKind.Offline : AIErrorKind.Http, error.Message);
            }

            using (response)
            {
                var text = await response.Content.ReadAsStringAsync(cancellation).ConfigureAwait(false);
                var status = (int)response.StatusCode;
                if (response.IsSuccessStatusCode) return text;
                if (response.StatusCode == HttpStatusCode.Unauthorized) throw new AIException(AIErrorKind.InvalidApiKey);
                if (status == 429 && ErrorCode(text) == "enforced_spend_limit_reached") throw new AIException(AIErrorKind.SpendCapReached, ErrorMessage(text), status);
                if (status is 429 or >= 500)
                {
                    if (attempt > 1) throw new AIException(AIErrorKind.Busy, ErrorMessage(text), status);
                    var delay = response.Headers.RetryAfter?.Delta is { } after ? TimeSpan.FromSeconds(Math.Min(after.TotalSeconds, 5)) : _retryDelay;
                    await Task.Delay(delay, cancellation).ConfigureAwait(false);
                    continue;
                }
                throw new AIException(AIErrorKind.Http, ErrorMessage(text), status);
            }
        }
    }

    public static ClaudeResponse Decode(string json)
    {
        try
        {
            var root = JsonNode.Parse(json) ?? throw new AIException(AIErrorKind.InvalidResponse);
            var blocks = root["content"] as JsonArray ?? [];
            var lastFallback = -1;
            for (var i = 0; i < blocks.Count; i++)
            {
                if (blocks[i]?["type"]?.GetValue<string>() == "fallback") lastFallback = i;
            }
            var text = string.Concat(blocks.Skip(lastFallback + 1)
                .Where(block => block?["type"]?.GetValue<string>() == "text")
                .Select(block => block?["text"]?.GetValue<string>() ?? ""));
            return new ClaudeResponse(text, root["stop_reason"]?.GetValue<string>());
        }
        catch (Exception error) when (error is System.Text.Json.JsonException or InvalidOperationException)
        {
            throw new AIException(AIErrorKind.InvalidResponse);
        }
    }

    private static string? ErrorMessage(string json) => TryParse(json)?["error"]?["message"]?.GetValue<string>();

    private static string? ErrorCode(string json) => TryParse(json)?["error"]?["details"]?["error_code"]?.GetValue<string>();

    private static JsonNode? TryParse(string json)
    {
        try
        {
            return JsonNode.Parse(json);
        }
        catch (System.Text.Json.JsonException)
        {
            return null;
        }
    }
}
