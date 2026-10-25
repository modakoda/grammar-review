using System.Runtime.CompilerServices;
using GrammarReview.Core.Checking;
using GrammarReview.Core.Harper;
using GrammarReview.Core.Issues;
using GrammarReview.Core.Settings;
using GrammarReview.Core.Text;

namespace GrammarReview.Core.Engine;

public interface ISpellChecker
{
    IReadOnlyList<TextIssue> Misspellings(string text, string? language, AppSettings settings);

    void Learn(string word);
}

public interface IProofreader
{
    Task<IReadOnlyList<AIEdit>> ProofreadAsync(string paragraph, string? language, string model, string apiKey, CancellationToken cancellation);
}

public enum AIState
{
    Disabled,
    Pending,
    Completed,
    MissingApiKey,
    TextTooLong,
    Failed,
}

public sealed record AIStatus(AIState State, string? Message = null)
{
    public static readonly AIStatus Disabled = new(AIState.Disabled);
    public static readonly AIStatus Pending = new(AIState.Pending);
    public static readonly AIStatus Completed = new(AIState.Completed);
}

/// <summary>The text to check. <paramref name="KeyboardLanguage"/> is used for spelling when the language is automatic.</summary>
public sealed record CheckRequest(string Text, AppSettings Settings, string? KeyboardLanguage = null);

public sealed record CheckResult(string Text, IReadOnlyList<TextIssue> Issues, AIStatus Status)
{
    public bool IsFinal => Status.State != AIState.Pending;
}

public sealed class ClaudeProofreader(ClaudeClient client) : IProofreader
{
    public async Task<IReadOnlyList<AIEdit>> ProofreadAsync(string paragraph, string? language, string model, string apiKey, CancellationToken cancellation)
    {
        var response = await client.CreateMessageAsync(CheckPrompt.Request(paragraph, language, model), apiKey, cancellation).ConfigureAwait(false);
        return CheckPrompt.Parse(response);
    }
}

/// <summary>Local spelling and Harper first, then the AI for each changed paragraph after a pause. Results stream in.</summary>
public sealed class GrammarEngine(ISpellChecker spelling, IProofreader proofreader, Func<string?> apiKey, HarperChecker? harper = null, EditCache? cache = null)
{
    public const int MaxConcurrentRequests = 3;

    private readonly EditCache _cache = cache ?? new EditCache();

    public void Learn(string word) => spelling.Learn(word);

    public async IAsyncEnumerable<CheckResult> CheckAsync(CheckRequest request, [EnumeratorCancellation] CancellationToken cancellation = default)
    {
        var text = request.Text;
        var settings = request.Settings;
        var localLanguage = settings.Language ?? request.KeyboardLanguage;
        var found = await Task.Run(() => spelling.Misspellings(text, localLanguage, settings), cancellation).ConfigureAwait(false);
        var offline = harper is null ? [] : await harper.IssuesAsync(text, localLanguage, settings, found, cancellation).ConfigureAwait(false);
        var local = found.Concat(offline).ToList();
        cancellation.ThrowIfCancellationRequested();

        var key = apiKey()?.Trim();
        var (paragraphs, status) = Plan(text, settings, key);
        yield return new CheckResult(text, IssueMerger.Merge(local, [], settings), status);
        if (status.State != AIState.Pending) yield break;

        var keys = paragraphs.Select(p => new EditCache.Key(settings.Model, settings.Language ?? "", p.Text)).ToList();
        var edits = keys.Select(_cache.Get).ToArray();
        if (edits.Any(e => e is null) && settings.AIDelaySeconds > 0)
        {
            await Task.Delay(TimeSpan.FromSeconds(settings.AIDelaySeconds), cancellation).ConfigureAwait(false);
        }

        var failures = new List<AIException>();
        using (var gate = new SemaphoreSlim(MaxConcurrentRequests))
        {
            var jobs = Enumerable.Range(0, paragraphs.Count).Where(i => edits[i] is null).Select(async index =>
            {
                await gate.WaitAsync(cancellation).ConfigureAwait(false);
                try
                {
                    var paragraph = paragraphs[index];
                    var answer = await proofreader.ProofreadAsync(paragraph.Text, settings.Language, settings.Model, key!, cancellation).ConfigureAwait(false);
                    edits[index] = EditLocator.Locate(answer, paragraph.Text);
                    _cache.Set(keys[index], edits[index]!);
                }
                catch (AIException error)
                {
                    lock (failures) failures.Add(error);
                }
                finally
                {
                    gate.Release();
                }
            }).ToList();
            await Task.WhenAll(jobs).ConfigureAwait(false);
        }
        cancellation.ThrowIfCancellationRequested();

        var ai = paragraphs.SelectMany((paragraph, index) => EditLocator.Issues(edits[index] ?? [], paragraph.Start)).ToList();
        var worst = failures.OrderBy(f => f.Kind == AIErrorKind.InvalidApiKey ? 0 : 1).FirstOrDefault();
        yield return new CheckResult(text, IssueMerger.Merge(local, ai, settings), worst is null ? AIStatus.Completed : new AIStatus(AIState.Failed, worst.UserMessage));
    }

    private static (IReadOnlyList<Paragraph> Paragraphs, AIStatus Status) Plan(string text, AppSettings settings, string? key)
    {
        if (!settings.AIEnabled) return ([], AIStatus.Disabled);
        if (text.Length > settings.MaxAICharacters) return ([], new AIStatus(AIState.TextTooLong));
        if (string.IsNullOrEmpty(key)) return ([], new AIStatus(AIState.MissingApiKey, new AIException(AIErrorKind.MissingApiKey).UserMessage));
        var paragraphs = ParagraphSplitter.Split(text).Where(ParagraphSplitter.IsWorthChecking).ToList();
        return (paragraphs, paragraphs.Count == 0 ? AIStatus.Completed : AIStatus.Pending);
    }
}

/// <summary>Remembers the AI's edits per paragraph, so editing one paragraph re-sends only that one.</summary>
public sealed class EditCache(int capacity = 500)
{
    public readonly record struct Key(string Model, string Language, string Text);

    private readonly Lock _gate = new();
    private readonly Dictionary<Key, LinkedListNode<(Key Key, IReadOnlyList<LocatedEdit> Edits)>> _entries = [];
    private readonly LinkedList<(Key Key, IReadOnlyList<LocatedEdit> Edits)> _order = [];

    public IReadOnlyList<LocatedEdit>? Get(Key key)
    {
        lock (_gate)
        {
            if (!_entries.TryGetValue(key, out var node)) return null;
            _order.Remove(node);
            _order.AddFirst(node);
            return node.Value.Edits;
        }
    }

    public void Set(Key key, IReadOnlyList<LocatedEdit> edits)
    {
        lock (_gate)
        {
            if (_entries.Remove(key, out var existing)) _order.Remove(existing);
            _entries[key] = _order.AddFirst((key, edits));
            while (_entries.Count > capacity && _order.Last is { } last)
            {
                _order.RemoveLast();
                _entries.Remove(last.Value.Key);
            }
        }
    }
}
