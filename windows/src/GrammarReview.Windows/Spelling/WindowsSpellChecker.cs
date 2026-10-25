using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using GrammarReview.Core.Engine;
using GrammarReview.Core.Issues;
using GrammarReview.Core.Settings;
using GrammarReview.Core.Text;

namespace GrammarReview.Windows.Spelling;

/// <summary>Spelling from the Windows Spell Checking API (spellcheck.h), in any language Windows has a dictionary for.</summary>
internal sealed class WindowsSpellChecker : GrammarReview.Core.Engine.ISpellChecker
{
    public const int MaxIssues = 200;
    public const int MaxGuesses = 3;

    private static readonly Guid FactoryClass = new("7ab36653-1796-484b-bdfa-e74f1db7c1dc");

    private readonly Lock _gate = new();
    private readonly Dictionary<string, INativeSpellChecker?> _checkers = new(StringComparer.OrdinalIgnoreCase);
    private ISpellCheckerFactory? _factory;
    private bool _unavailable;

    public IReadOnlyList<TextIssue> Misspellings(string text, string? language, AppSettings settings)
    {
        lock (_gate)
        {
            if (Checker(language ?? "en-US") is not { } checker) return [];
            var protectedSpans = ProtectedRanges.Find(text);
            var issues = new List<TextIssue>();
            try
            {
                var errors = checker.Check(text);
                while (issues.Count < MaxIssues && errors.Next(out var error) == 0 && error is not null)
                {
                    var span = new TextSpan((int)error.StartIndex, (int)error.Length);
                    if (!span.Fits(text) || span.Length == 0 || protectedSpans.Any(span.Overlaps)) continue;
                    var word = text.Substring(span.Start, span.Length);
                    if (settings.IsInPersonalDictionary(word) || IsAcronym(word)) continue;
                    if (Issue(checker, error, span, word, text) is { } issue) issues.Add(issue);
                }
            }
            catch (COMException)
            {
            }
            return issues;
        }
    }

    public void Learn(string word)
    {
        lock (_gate)
        {
            foreach (var checker in _checkers.Values.OfType<INativeSpellChecker>())
            {
                try
                {
                    checker.Add(word.Trim());
                }
                catch (COMException)
                {
                }
            }
        }
    }

    private static TextIssue? Issue(INativeSpellChecker checker, ISpellingError error, TextSpan span, string word, string text)
    {
        switch (error.CorrectiveAction)
        {
            case CorrectiveAction.Delete:
                var start = span.Start > 0 && text[span.Start - 1] == ' ' ? span.Start - 1 : span.Start;
                var repeated = new TextSpan(start, span.End - start);
                return new TextIssue(repeated, text.Substring(repeated.Start, repeated.Length), [""], "Repeated word.", IssueCategory.Grammar, IssueSource.Local);
            case CorrectiveAction.Replace:
                return new TextIssue(span, word, [error.Replacement], "Possible spelling mistake.", IssueCategory.Spelling, IssueSource.Local);
            case CorrectiveAction.GetSuggestions:
                var guesses = Suggestions(checker, word).Where(guess => guess != word).Distinct().Take(MaxGuesses).ToList();
                return new TextIssue(span, word, guesses, guesses.Count == 0 ? "Unknown word." : "Possible spelling mistake.", IssueCategory.Spelling, IssueSource.Local);
            default:
                return null;
        }
    }

    private static IEnumerable<string> Suggestions(INativeSpellChecker checker, string word)
    {
        var list = new List<string>();
        var enumerator = checker.Suggest(word);
        var item = new string[1];
        while (list.Count < 10 && enumerator.Next(1, item, IntPtr.Zero) == 0) list.Add(item[0]);
        return list;
    }

    private static bool IsAcronym(string word)
    {
        var letters = word.Where(char.IsLetter).ToList();
        if (letters.Count < 2) return false;
        if (letters.All(char.IsUpper)) return true;
        return letters[^1] == 's' && letters.Count >= 3 && letters.SkipLast(1).All(char.IsUpper);
    }

    private INativeSpellChecker? Checker(string language)
    {
        if (_checkers.TryGetValue(language, out var cached)) return cached;
        INativeSpellChecker? checker = null;
        if (Factory() is { } factory)
        {
            try
            {
                var tag = factory.IsSupported(language) ? language : SupportedLike(factory, language);
                if (tag is not null) checker = factory.CreateSpellChecker(tag);
            }
            catch (COMException)
            {
            }
        }
        _checkers[language] = checker;
        return checker;
    }

    private static string? SupportedLike(ISpellCheckerFactory factory, string language)
    {
        var prefix = language.Split('-', '_')[0];
        var supported = factory.SupportedLanguages;
        var item = new string[1];
        while (supported.Next(1, item, IntPtr.Zero) == 0)
        {
            if (item[0].Split('-')[0].Equals(prefix, StringComparison.OrdinalIgnoreCase)) return item[0];
        }
        return null;
    }

    private ISpellCheckerFactory? Factory()
    {
        if (_factory is not null || _unavailable) return _factory;
        try
        {
            var type = Type.GetTypeFromCLSID(FactoryClass, throwOnError: false);
            _factory = type is null ? null : Activator.CreateInstance(type) as ISpellCheckerFactory;
        }
        catch (COMException)
        {
            _factory = null;
        }
        _unavailable = _factory is null;
        return _factory;
    }

    private enum CorrectiveAction
    {
        None = 0,
        GetSuggestions = 1,
        Replace = 2,
        Delete = 3,
    }

    [ComImport]
    [Guid("8e018a9d-2415-4677-bf08-794ea61f94bb")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ISpellCheckerFactory
    {
        IEnumString SupportedLanguages { get; }

        [return: MarshalAs(UnmanagedType.Bool)]
        bool IsSupported([MarshalAs(UnmanagedType.LPWStr)] string languageTag);

        INativeSpellChecker CreateSpellChecker([MarshalAs(UnmanagedType.LPWStr)] string languageTag);
    }

    [ComImport]
    [Guid("b6fd0b71-e2bc-4653-8d05-f197e412770b")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface INativeSpellChecker
    {
        string LanguageTag { [return: MarshalAs(UnmanagedType.LPWStr)] get; }

        IEnumSpellingError Check([MarshalAs(UnmanagedType.LPWStr)] string text);

        IEnumString Suggest([MarshalAs(UnmanagedType.LPWStr)] string word);

        void Add([MarshalAs(UnmanagedType.LPWStr)] string word);

        void Ignore([MarshalAs(UnmanagedType.LPWStr)] string word);

        void AutoCorrect([MarshalAs(UnmanagedType.LPWStr)] string from, [MarshalAs(UnmanagedType.LPWStr)] string to);

        byte GetOptionValue([MarshalAs(UnmanagedType.LPWStr)] string optionId);

        IEnumString OptionIds { get; }

        string Id { [return: MarshalAs(UnmanagedType.LPWStr)] get; }

        string LocalizedName { [return: MarshalAs(UnmanagedType.LPWStr)] get; }

        uint AddSpellCheckerChanged(IntPtr handler);

        void RemoveSpellCheckerChanged(uint cookie);

        IntPtr GetOptionDescription([MarshalAs(UnmanagedType.LPWStr)] string optionId);

        IEnumSpellingError ComprehensiveCheck([MarshalAs(UnmanagedType.LPWStr)] string text);
    }

    [ComImport]
    [Guid("803e3bd4-2828-4410-8290-418d1d73c762")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface IEnumSpellingError
    {
        [PreserveSig]
        int Next(out ISpellingError? value);
    }

    [ComImport]
    [Guid("b7c82d61-fbe8-4b47-9b27-6c0d2e0de0a3")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private interface ISpellingError
    {
        uint StartIndex { get; }

        uint Length { get; }

        CorrectiveAction CorrectiveAction { get; }

        string Replacement { [return: MarshalAs(UnmanagedType.LPWStr)] get; }
    }
}
