using System.Diagnostics;

namespace GrammarReview.Core.Harper;

public abstract record HarperInstallation
{
    public sealed record Found(string Path, string Version) : HarperInstallation;

    public sealed record NotFound : HarperInstallation;

    public sealed record Unusable(string Path, string Reason) : HarperInstallation;
}

public static class HarperProbe
{
    public static readonly TimeSpan Timeout = TimeSpan.FromSeconds(5);

    public static async Task<HarperInstallation> InstallationAsync(string customPath, HarperLocator? locator = null, CancellationToken cancellation = default)
    {
        switch ((locator ?? new HarperLocator()).Locate(customPath))
        {
            case HarperLocation.Found(var path):
                return await VersionAsync(path, cancellation).ConfigureAwait(false) is { } output
                    ? new HarperInstallation.Found(path, Version(output))
                    : new HarperInstallation.Unusable(path, "harper-ls didn't start. Reinstall it, or choose another copy.");
            case HarperLocation.Invalid(var path):
                return new HarperInstallation.Unusable(path, "There's no harper-ls program at this path.");
            default:
                return new HarperInstallation.NotFound();
        }
    }

    public static string Version(string output) =>
        output.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries).LastOrDefault(word => char.IsDigit(word[0])) ?? "unknown";

    private static async Task<string?> VersionAsync(string executable, CancellationToken cancellation)
    {
        try
        {
            using var process = Process.Start(new ProcessStartInfo(executable, "--version")
            {
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                CreateNoWindow = true,
            });
            if (process is null) return null;
            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellation);
            timeout.CancelAfter(Timeout);
            var output = await process.StandardOutput.ReadToEndAsync(timeout.Token).ConfigureAwait(false);
            await process.WaitForExitAsync(timeout.Token).ConfigureAwait(false);
            return process.ExitCode == 0 ? output : null;
        }
        catch (Exception error) when (error is System.ComponentModel.Win32Exception or InvalidOperationException or OperationCanceledException or IOException)
        {
            return null;
        }
    }
}
