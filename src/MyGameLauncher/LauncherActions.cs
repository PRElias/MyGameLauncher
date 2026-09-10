using System.Diagnostics;

namespace MyGameLauncher;

internal sealed class LauncherActions(Action<string> log)
{
    private const string SteamVr = "steam://rungameid/250820";
    private const string Obs = @"C:\Program Files\obs-studio\bin\64bit\obs64.exe";
    private const string CrewChief = @"C:\Program Files (x86)\Britton IT Ltd\CrewChiefV4\CrewChiefV4.exe";
    private const string TradingPaints = @"C:\Program Files (x86)\Rhinode LLC\Trading Paints\Trading Paints.exe";
    private static readonly string Discord = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), @"Discord\Update.exe");
    private const string IRacing = @"C:\Program Files (x86)\iRacing\ui\iRacingUI.exe";

    private static readonly DisplayRequest GameDisplay = DisplayRequest.Max(2560, 1440);
    private static readonly DisplayRequest DesktopDisplay = DisplayRequest.Max(3440, 1440);

    public async Task RunSimRacingAsync(CancellationToken cancellationToken)
    {
        log("Iniciando ambiente de simulacao...");
        StopBackgroundApplications();
        ApplyDisplay("simracing", GameDisplay);

        await DelaySeconds(10, cancellationToken);
        StartRequiredProcess("SteamVR", SteamVr);

        await DelaySeconds(10, cancellationToken);
        StartRequiredProcess("CrewChief", CrewChief);

        await DelaySeconds(5, cancellationToken);
        StartRequiredProcess("Discord", Discord, ["--processStart", "Discord.exe"]);

        await DelaySeconds(3, cancellationToken);
        StartRequiredProcess("Trading Paints", TradingPaints);

        await DelaySeconds(3, cancellationToken);
        StartRequiredProcess("OBS Studio", Obs, workingDirectory: Path.GetDirectoryName(Obs));

        StartRequiredProcess("iRacing", IRacing);

        log("Ambiente de simulacao iniciado.");
    }

    public Task RunStreamingAsync()
    {
        log("Aplicando modo streaming sem abrir ou fechar programas...");
        ApplyDisplay("streaming", GameDisplay);
        return Task.CompletedTask;
    }

    public Task RunDesktopAsync()
    {
        log("Restaurando modo desktop...");
        ApplyDisplay("desktop", DesktopDisplay);
        return Task.CompletedTask;
    }

    public Task RunIRacingBorderlessAsync()
    {
        log("Aplicando borderless no iRacing...");
        if (!BorderlessWindow.ApplyToIRacing(log))
        {
            log("Falha - abra a sessao do iRacing e tente novamente.");
        }

        return Task.CompletedTask;
    }

    public Task ClearShaderCachesAsync(CancellationToken cancellationToken) =>
        Task.Run(() =>
        {
            log("Limpando caches de shaders e DirectX...");

            var deletedFiles = 0;
            var deletedDirectories = 0;
            var skippedEntries = 0;

            foreach (var folder in GetShaderCacheFolders())
            {
                cancellationToken.ThrowIfCancellationRequested();

                if (!Directory.Exists(folder.Path))
                {
                    log($"Ignorado - {folder.Name}: pasta nao encontrada.");
                    continue;
                }

                log($"Limpando {folder.Name}: {folder.Path}");

                string[] entries;
                try
                {
                    entries = Directory.EnumerateFileSystemEntries(folder.Path).ToArray();
                }
                catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
                {
                    skippedEntries++;
                    log($"Aviso - nao foi possivel acessar {folder.Name}: {ex.Message}");
                    continue;
                }

                foreach (var entry in entries)
                {
                    cancellationToken.ThrowIfCancellationRequested();

                    if (TryDeleteCacheEntry(entry, ref deletedFiles, ref deletedDirectories))
                    {
                        continue;
                    }

                    skippedEntries++;
                    log($"Aviso - nao foi possivel apagar: {entry}");
                }
            }

            log($"Limpeza concluida. Arquivos apagados: {deletedFiles}; pastas apagadas: {deletedDirectories}; itens ignorados: {skippedEntries}.");
            log("O driver e os jogos vao recriar esses caches no proximo uso.");
        }, cancellationToken);

    private void ApplyDisplay(string name, DisplayRequest request)
    {
        var ok = DisplayManager.Apply(request, log);
        log(ok
            ? $"OK - Resolucao aplicada para {name}."
            : $"Falha - Windows recusou a resolucao para {name}.");
    }

    private static IEnumerable<(string Name, string Path)> GetShaderCacheFolders()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        var commonAppData = Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData);
        var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var localLow = Path.Combine(userProfile, "AppData", "LocalLow");

        return
        [
            ("NVIDIA DXCache", Path.Combine(localAppData, "NVIDIA", "DXCache")),
            ("NVIDIA GLCache", Path.Combine(localAppData, "NVIDIA", "GLCache")),
            ("NVIDIA NV_Cache", Path.Combine(localAppData, "NVIDIA Corporation", "NV_Cache")),
            ("NVIDIA PerDriverVersion DXCache", Path.Combine(localLow, "NVIDIA", "PerDriverVersion", "DXCache")),
            ("NVIDIA PerDriverVersion GLCache", Path.Combine(localLow, "NVIDIA", "PerDriverVersion", "GLCache")),
            ("NVIDIA LocalLow DXCache", Path.Combine(localLow, "NVIDIA", "DXCache")),
            ("NVIDIA LocalLow GLCache", Path.Combine(localLow, "NVIDIA", "GLCache")),
            ("NVIDIA ProgramData NV_Cache", Path.Combine(commonAppData, "NVIDIA Corporation", "NV_Cache")),
            ("DirectX D3DSCache", Path.Combine(localAppData, "D3DSCache")),
            ("DirectX Microsoft D3DSCache", Path.Combine(localAppData, "Microsoft", "D3DSCache"))
        ];
    }

    private static bool TryDeleteCacheEntry(string entry, ref int deletedFiles, ref int deletedDirectories)
    {
        try
        {
            if (File.Exists(entry))
            {
                File.SetAttributes(entry, FileAttributes.Normal);
                File.Delete(entry);
                deletedFiles++;
                return true;
            }

            if (Directory.Exists(entry))
            {
                ClearReadOnlyAttributes(entry);
                Directory.Delete(entry, recursive: true);
                deletedDirectories++;
                return true;
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            return false;
        }

        return false;
    }

    private static void ClearReadOnlyAttributes(string directory)
    {
        foreach (var file in Directory.EnumerateFiles(directory, "*", SearchOption.AllDirectories))
        {
            File.SetAttributes(file, FileAttributes.Normal);
        }
    }

    private void StopBackgroundApplications()
    {
        string[] processNames =
        [
            "OneDrive",
            "FileSyncHelper",
            "tailscale-ipn",
            "tailscaled",
            "sunshinesvc",
            "sunshine"
        ];

        foreach (var name in processNames)
        {
            foreach (var process in Process.GetProcessesByName(name))
            {
                try
                {
                    process.Kill(entireProcessTree: true);
                    log($"OK - processo encerrado: {name}");
                }
                catch (Exception ex)
                {
                    log($"Aviso - nao foi possivel encerrar {name}: {ex.Message}");
                }
            }
        }

        RunTaskKill(processNames);
        StopService("Tailscale");
        StopService("Sunshine");
    }

    private void RunTaskKill(IEnumerable<string> processNames)
    {
        foreach (var name in processNames)
        {
            try
            {
                using var process = Process.Start(new ProcessStartInfo
                {
                    FileName = "taskkill.exe",
                    Arguments = $"/F /T /IM \"{name}.exe\"",
                    CreateNoWindow = true,
                    UseShellExecute = false,
                    RedirectStandardOutput = true,
                    RedirectStandardError = true
                });
                process?.WaitForExit(3000);
            }
            catch
            {
                // The direct Process.Kill path above already reports useful failures.
            }
        }
    }

    private void StopService(string serviceName)
    {
        try
        {
            using var process = Process.Start(new ProcessStartInfo
            {
                FileName = "sc.exe",
                Arguments = $"stop \"{serviceName}\"",
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            });
            process?.WaitForExit(5000);
        }
        catch (Exception ex)
        {
            log($"Aviso - nao foi possivel parar o servico {serviceName}: {ex.Message}");
        }
    }

    private void StartRequiredProcess(string name, string fileName, string[]? arguments = null, string? workingDirectory = null)
    {
        try
        {
            if (!fileName.Contains("://", StringComparison.Ordinal) && !File.Exists(fileName))
            {
                throw new FileNotFoundException("Arquivo nao encontrado.", fileName);
            }

            var startInfo = new ProcessStartInfo
            {
                FileName = fileName,
                UseShellExecute = true
            };

            if (arguments is { Length: > 0 })
            {
                foreach (var argument in arguments)
                {
                    startInfo.ArgumentList.Add(argument);
                }
            }

            if (!string.IsNullOrWhiteSpace(workingDirectory))
            {
                startInfo.WorkingDirectory = workingDirectory;
            }

            Process.Start(startInfo);
            log($"OK - {name}");
        }
        catch (Exception ex)
        {
            log($"Falha - {name}: {ex.Message}");
        }
    }

    private static Task DelaySeconds(int seconds, CancellationToken cancellationToken) =>
        Task.Delay(TimeSpan.FromSeconds(seconds), cancellationToken);
}
