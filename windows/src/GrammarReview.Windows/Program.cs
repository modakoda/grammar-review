namespace GrammarReview.Windows;

internal static class Program
{
    [STAThread]
    private static void Main()
    {
        using var instance = new Mutex(true, @"Local\GrammarReview", out var isFirst);
        if (!isFirst) return;
        ApplicationConfiguration.Initialize();
        Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
        Application.ThreadException += (_, e) => System.Diagnostics.Trace.TraceError($"Grammar Review: {e.Exception}");
        using var app = new TrayApplication();
        Application.Run(app);
    }
}
