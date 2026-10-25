using System.Collections.Concurrent;

namespace GrammarReview.Windows.Accessibility;

/// <summary>
/// Every UI Automation call runs on this one MTA thread: UI Automation shouldn't be called from the UI
/// thread, and a slow app then only delays this queue, never the overlays.
/// </summary>
internal sealed class UiaThread : IDisposable
{
    private readonly BlockingCollection<Action> _work = [];
    private readonly Thread _thread;

    public UiaThread()
    {
        _thread = new Thread(Run) { IsBackground = true, Name = "UI Automation" };
        _thread.SetApartmentState(ApartmentState.MTA);
        _thread.Start();
    }

    public Task<T> RunAsync<T>(Func<T> work)
    {
        var result = new TaskCompletionSource<T>(TaskCreationOptions.RunContinuationsAsynchronously);
        try
        {
            _work.Add(() =>
            {
                try
                {
                    result.SetResult(work());
                }
                catch (Exception error)
                {
                    result.SetException(error);
                }
            });
        }
        catch (InvalidOperationException)
        {
            result.SetCanceled();
        }
        return result.Task;
    }

    public void Dispose() => _work.CompleteAdding();

    private void Run()
    {
        foreach (var action in _work.GetConsumingEnumerable()) action();
    }
}
