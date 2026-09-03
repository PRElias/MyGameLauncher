# Caminhos configuráveis. Ajuste apenas os valores que forem diferentes no seu PC.
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$SteamVR = "steam://rungameid/250820"
$OBS = "C:\Program Files\obs-studio\bin\64bit\obs64.exe"
$CrewChiefCandidates = "C:\Program Files (x86)\Britton IT Ltd\CrewChiefV4\CrewChiefV4.exe"
$TradingPaints = "C:\Program Files (x86)\Rhinode LLC\Trading Paints\Trading Paints.exe"
$Discord = "$env:LocalAppData\Discord\Update.exe"
$iRacing = "C:\Program Files (x86)\iRacing\ui\iRacingUI.exe"
$TargetWidth = 2560
$TargetHeight = 1440
$TargetRefreshRate = "Max" # Use "Max" para maior frequencia disponivel, $null para deixar o Windows escolher, ou 174.96 para forcar.
$RestoreDisplayOnLauncherExit = $true
$RestoreWidth = 3440
$RestoreHeight = 1440
$RestoreRefreshRate = "Max"

$failures = [System.Collections.Generic.List[string]]::new()
$displayRestoreAttempted = $false
$consoleCloseHandler = $null

function Format-RefreshRate {
    param([object]$RefreshRate)

    if ($null -eq $RefreshRate) {
        return "Windows"
    }
    if ($RefreshRate -is [string] -and $RefreshRate.Equals("Max", [System.StringComparison]::OrdinalIgnoreCase)) {
        return "maior frequencia disponivel"
    }
    return "$RefreshRate Hz"
}

function Set-ScreenResolution {
    param(
        [int]$Width,
        [int]$Height,
        [object]$RefreshRate = $null
    )

    if (-not ([System.Management.Automation.PSTypeName]'Display.NativeMethods').Type) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
namespace Display {
    public static class NativeMethods {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
        public struct DEVMODE {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
            public short dmSpecVersion, dmDriverVersion, dmSize, dmDriverExtra;
            public int dmFields, dmPositionX, dmPositionY, dmDisplayOrientation, dmDisplayFixedOutput;
            public short dmColor, dmDuplex, dmYResolution, dmTTOption, dmCollate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
            public short dmLogPixels;
            public int dmBitsPerPel, dmPelsWidth, dmPelsHeight, dmDisplayFlags, dmDisplayFrequency;
        }
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
        public struct DISPLAY_DEVICE {
            public int cb;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
            public int StateFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
        }
        [DllImport("user32.dll", CharSet = CharSet.Ansi)]
        public static extern bool EnumDisplayDevices(string lpDevice, int iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, int dwFlags);
        [DllImport("user32.dll", CharSet = CharSet.Ansi)]
        public static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);
        [DllImport("user32.dll", CharSet = CharSet.Ansi)]
        public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);
        [DllImport("user32.dll", CharSet = CharSet.Ansi)]
        public static extern int ChangeDisplaySettingsEx(string deviceName, ref DEVMODE devMode, IntPtr hwnd, int flags, IntPtr lParam);
        public const int ENUM_CURRENT_SETTINGS = -1;
        public const int ENUM_REGISTRY_SETTINGS = -2;
        public const int DISPLAY_DEVICE_PRIMARY_DEVICE = 0x4;
        public const int DM_BITSPERPEL = 0x40000, DM_PELSWIDTH = 0x80000, DM_PELSHEIGHT = 0x100000, DM_DISPLAYFREQUENCY = 0x400000;
        public const int DISP_CHANGE_SUCCESSFUL = 0;
    }
}
"@
    }

    $deviceName = $null
    $displayDevice = New-Object Display.NativeMethods+DISPLAY_DEVICE
    $displayDevice.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($displayDevice)
    for ($index = 0; [Display.NativeMethods]::EnumDisplayDevices($null, $index, [ref]$displayDevice, 0); $index++) {
        if (($displayDevice.StateFlags -band [Display.NativeMethods]::DISPLAY_DEVICE_PRIMARY_DEVICE) -ne 0) {
            $deviceName = $displayDevice.DeviceName
            break
        }
        $displayDevice = New-Object Display.NativeMethods+DISPLAY_DEVICE
        $displayDevice.cb = [System.Runtime.InteropServices.Marshal]::SizeOf($displayDevice)
    }

    $requestedRefreshRate = $null
    $useMaxRefreshRate = $false
    if ($null -ne $RefreshRate) {
        if ($RefreshRate -is [string] -and $RefreshRate.Equals("Max", [System.StringComparison]::OrdinalIgnoreCase)) {
            $useMaxRefreshRate = $true
        } else {
            $requestedRefreshRate = [int][Math]::Round([double]$RefreshRate)
        }
    }

    $modes = [System.Collections.Generic.List[object]]::new()
    $modeIndex = 0
    do {
        $candidate = New-Object Display.NativeMethods+DEVMODE
        $candidate.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($candidate)
        $foundMode = [Display.NativeMethods]::EnumDisplaySettings($deviceName, $modeIndex, [ref]$candidate)
        if ($foundMode -and $candidate.dmPelsWidth -eq $Width -and $candidate.dmPelsHeight -eq $Height) {
            $modes.Add([pscustomobject]@{
                Mode = $candidate
                Frequency = $candidate.dmDisplayFrequency
                Distance = if ($null -ne $requestedRefreshRate) { [Math]::Abs($candidate.dmDisplayFrequency - $requestedRefreshRate) } else { 0 }
                BitsPerPel = $candidate.dmBitsPerPel
            })
        }
        $modeIndex++
    } while ($foundMode)

    if ($useMaxRefreshRate) {
        $modesToTry = $modes | Sort-Object Frequency, BitsPerPel -Descending
    } elseif ($null -ne $requestedRefreshRate) {
        $modesToTry = $modes | Sort-Object Distance, Frequency
    } else {
        $modesToTry = @()
    }

    foreach ($entry in $modesToTry) {
        $modeToTry = $entry.Mode
        $modeToTry.dmFields = [Display.NativeMethods]::DM_BITSPERPEL -bor [Display.NativeMethods]::DM_PELSWIDTH -bor [Display.NativeMethods]::DM_PELSHEIGHT -bor [Display.NativeMethods]::DM_DISPLAYFREQUENCY
        Write-Host "Tentando modo: $($modeToTry.dmPelsWidth)x$($modeToTry.dmPelsHeight) @ $($modeToTry.dmDisplayFrequency) Hz" -ForegroundColor Cyan

        $result = [Display.NativeMethods]::ChangeDisplaySettingsEx($deviceName, [ref]$modeToTry, [IntPtr]::Zero, 0, [IntPtr]::Zero)
        if ($result -eq [Display.NativeMethods]::DISP_CHANGE_SUCCESSFUL) {
            return $true
        }

        $fallbackResult = [Display.NativeMethods]::ChangeDisplaySettings([ref]$modeToTry, 0)
        if ($fallbackResult -eq [Display.NativeMethods]::DISP_CHANGE_SUCCESSFUL) {
            return $true
        }

        Write-Warning "Modo recusado: $($modeToTry.dmPelsWidth)x$($modeToTry.dmPelsHeight) @ $($modeToTry.dmDisplayFrequency) Hz (codigos $result/$fallbackResult)."
    }

    $directMode = New-Object Display.NativeMethods+DEVMODE
    $directMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($directMode)
    $directMode.dmPelsWidth = $Width
    $directMode.dmPelsHeight = $Height
    $directMode.dmBitsPerPel = 32
    $directMode.dmFields = [Display.NativeMethods]::DM_BITSPERPEL -bor [Display.NativeMethods]::DM_PELSWIDTH -bor [Display.NativeMethods]::DM_PELSHEIGHT
    if ($null -ne $requestedRefreshRate) {
        $directMode.dmDisplayFrequency = $requestedRefreshRate
        $directMode.dmFields = $directMode.dmFields -bor [Display.NativeMethods]::DM_DISPLAYFREQUENCY
    }

    if ($modes.Count -eq 0) {
        Write-Warning "Nao foi possivel localizar um modo enumerado para ${Width}x${Height}. Usando alteracao direta."
    } else {
        Write-Warning "Todos os modos enumerados para ${Width}x${Height} foram recusados. Usando alteracao direta."
    }

    $directResult = [Display.NativeMethods]::ChangeDisplaySettingsEx($deviceName, [ref]$directMode, [IntPtr]::Zero, 0, [IntPtr]::Zero)
    if ($directResult -eq [Display.NativeMethods]::DISP_CHANGE_SUCCESSFUL) {
        return $true
    }

    $globalDirectResult = [Display.NativeMethods]::ChangeDisplaySettings([ref]$directMode, 0)
    if ($globalDirectResult -eq [Display.NativeMethods]::DISP_CHANGE_SUCCESSFUL) {
        return $true
    }

    if ($null -ne $requestedRefreshRate) {
        Write-Warning "Alteracao direta com frequencia foi recusada (codigos $directResult/$globalDirectResult). Tentando apenas resolucao."
        $resolutionOnlyMode = New-Object Display.NativeMethods+DEVMODE
        $resolutionOnlyMode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($resolutionOnlyMode)
        $resolutionOnlyMode.dmPelsWidth = $Width
        $resolutionOnlyMode.dmPelsHeight = $Height
        $resolutionOnlyMode.dmFields = [Display.NativeMethods]::DM_PELSWIDTH -bor [Display.NativeMethods]::DM_PELSHEIGHT
        $resolutionOnlyResult = [Display.NativeMethods]::ChangeDisplaySettings([ref]$resolutionOnlyMode, 0)
        return $resolutionOnlyResult -eq [Display.NativeMethods]::DISP_CHANGE_SUCCESSFUL
    }

    return $false
}

function Start-RequiredProcess {
    param(
        [string]$Name,
        [string]$FilePath,
        [string[]]$ArgumentList = @(),
        [string]$WorkingDirectory
    )

    try {
        if ($FilePath -notlike '*://*' -and -not (Test-Path -LiteralPath $FilePath)) {
            throw "Arquivo não encontrado: $FilePath"
        }
        $parameters = @{ FilePath = $FilePath; ErrorAction = 'Stop' }
        if ($ArgumentList.Count -gt 0) { $parameters.ArgumentList = $ArgumentList }
        if ($WorkingDirectory) { $parameters.WorkingDirectory = $WorkingDirectory }
        Start-Process @parameters | Out-Null
        Write-Host "OK - $Name" -ForegroundColor Green
        return $true
    } catch {
        $failures.Add($Name)
        Write-Warning "Falha - ${Name}: $($_.Exception.Message)"
        return $false
    }
}

function Stop-BackgroundApplications {
    $processNames = @(
        "OneDrive",
        "FileSyncHelper",
        "tailscale-ipn",
        "tailscaled",
        "sunshinesvc",
		"sunshine"
    )
    Get-Process -Name $processNames -ErrorAction SilentlyContinue |
        Stop-Process -Force -ErrorAction SilentlyContinue

    $serviceNames = @("Tailscale", "Sunshine")
    Get-Service -Name $serviceNames -ErrorAction SilentlyContinue |
        Where-Object { $_.Status -ne "Stopped" } |
        Stop-Service -Force -ErrorAction SilentlyContinue

    foreach ($processName in $processNames) {
        & taskkill.exe /F /T /IM "$processName.exe" *> $null
    }
}

function Set-IRacingBorderless {
    if (-not ([System.Management.Automation.PSTypeName]'Win32').Type) {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class Win32 {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
}
"@
    }

    $process = Get-Process -Name "iRacingSim64DX11" -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
        Select-Object -First 1

    if (-not $process) {
        throw "Processo do iRacing nao encontrado ou a janela ainda nao carregou."
    }

    $hwnd = $process.MainWindowHandle
    $GWL_STYLE = -16
    $WS_CAPTION = 0x00C00000
    $WS_THICKFRAME = 0x00040000
    $SWP_FRAMECHANGED = 0x0020
    $SWP_SHOWWINDOW = 0x0040

    Add-Type -AssemblyName System.Windows.Forms
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $width = $screen.Width
    $height = $screen.Height

    $style = [Win32]::GetWindowLong($hwnd, $GWL_STYLE)
    $style = $style -band (-bnot ($WS_CAPTION -bor $WS_THICKFRAME))
    [Win32]::SetWindowLong($hwnd, $GWL_STYLE, $style) | Out-Null
    [Win32]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, $width, $height, ($SWP_FRAMECHANGED -bor $SWP_SHOWWINDOW)) | Out-Null

    Write-Host "Sucesso! Janela do iRacing ajustada para Borderless ($width x $height)." -ForegroundColor Green
}

function Wait-ForIRacingWindow {
    param(
        [int]$TimeoutSeconds = 720
    )

    Write-Host "Aguardando a janela do iRacing..."
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    do {
        $process = Get-Process -Name "iRacingSim64DX11" -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } |
            Select-Object -First 1

        if ($process) {
            Write-Host "Janela do iRacing detectada. Aplicando modo borderless..." -ForegroundColor Cyan
            try {
                Set-IRacingBorderless
                return $true
            } catch {
                $failures.Add("Modo borderless")
                Write-Warning "Falha - Modo borderless: $($_.Exception.Message)"
                return $false
            }
        }

        Start-Sleep -Seconds 2
    } while ((Get-Date) -lt $deadline)

    $failures.Add("Detecção da janela do iRacing")
    Write-Warning "A janela do iRacing nao foi detectada em $TimeoutSeconds segundos."
    return $false
}

function Wait-ForLauncherExit {
    Write-Host ""
    Write-Host "Ambiente iniciado. Deixe esta janela aberta enquanto estiver usando o simulador." -ForegroundColor Cyan
    $restoreRefreshDescription = Format-RefreshRate -RefreshRate $RestoreRefreshRate
    Write-Host "Pressione Enter para restaurar ${RestoreWidth}x${RestoreHeight} usando $restoreRefreshDescription."
    Write-Host "Fechar a janela pelo X tambem tenta restaurar, mas Enter e mais confiavel."
    try {
        Read-Host | Out-Null
    } catch {
        Write-Warning "Entrada encerrada. Restaurando a tela."
    }
}

function Restore-DesktopDisplay {
    if (-not $RestoreDisplayOnLauncherExit) {
        return
    }
    if ($script:displayRestoreAttempted) {
        return
    }
    $script:displayRestoreAttempted = $true

    $restoreRefreshDescription = Format-RefreshRate -RefreshRate $RestoreRefreshRate
    Write-Host "Restaurando resolução para ${RestoreWidth}x${RestoreHeight} usando $restoreRefreshDescription..." -ForegroundColor Cyan
    try {
        if (-not (Set-ScreenResolution -Width $RestoreWidth -Height $RestoreHeight -RefreshRate $RestoreRefreshRate)) {
            throw "O Windows recusou a restauracao de resolucao."
        }
        Write-Host "OK - Resolucao restaurada" -ForegroundColor Green
    } catch {
        $failures.Add("Restauração de resolução")
        Write-Warning "Falha - Restauração de resolução: $($_.Exception.Message)"
    }
}

function Register-ConsoleCloseHandler {
    if (-not ([System.Management.Automation.PSTypeName]'Console.NativeMethods').Type) {
        Add-Type @"
using System;
using System.Runtime.InteropServices;
namespace Console {
    public static class NativeMethods {
        public delegate bool ConsoleCtrlHandler(int ctrlType);

        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetConsoleCtrlHandler(ConsoleCtrlHandler handler, bool add);
    }
}
"@
    }

    $script:consoleCloseHandler = [Console.NativeMethods+ConsoleCtrlHandler]{
        param([int]$ctrlType)
        Restore-DesktopDisplay
        Start-Sleep -Seconds 2
        return $false
    }

    [Console.NativeMethods]::SetConsoleCtrlHandler($script:consoleCloseHandler, $true) | Out-Null
}

Register-ConsoleCloseHandler

$null = Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
    Restore-DesktopDisplay
}

try {
    Stop-BackgroundApplications

    Write-Host "Iniciando ambiente de simulação..." -ForegroundColor Cyan

    $refreshDescription = Format-RefreshRate -RefreshRate $TargetRefreshRate
    Write-Host "1. Alterando resolução para ${TargetWidth}x${TargetHeight} usando $refreshDescription..."
    try {
        if (-not (Set-ScreenResolution -Width $TargetWidth -Height $TargetHeight -RefreshRate $TargetRefreshRate)) { throw "O Windows recusou a alteração de resolução." }
        Write-Host "OK - Resolução alterada" -ForegroundColor Green
    } catch {
        $failures.Add("Alteração de resolução")
        Write-Warning "Falha - Alteração de resolução: $($_.Exception.Message)"
    }
    Start-Sleep -Seconds 10

    Start-RequiredProcess -Name "SteamVR" -FilePath $SteamVR | Out-Null
    Start-Sleep -Seconds 10

    $crewChief = $CrewChiefCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    Start-RequiredProcess -Name "CrewChief" -FilePath $crewChief | Out-Null
    Start-Sleep -Seconds 5

    Start-RequiredProcess -Name "Discord" -FilePath $Discord -ArgumentList @('--processStart', 'Discord.exe') | Out-Null
    Start-Sleep -Seconds 3

    Start-RequiredProcess -Name "Trading Paints" -FilePath $TradingPaints | Out-Null
    Start-Sleep -Seconds 3

    Start-RequiredProcess -Name "OBS Studio" -FilePath $OBS -WorkingDirectory (Split-Path -Parent $OBS) | Out-Null

    $iRacing = $iRacing | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
    Start-RequiredProcess -Name "iRacing" -FilePath $iRacing | Out-Null
    Wait-ForIRacingWindow | Out-Null

    if ($failures.Count -eq 0) {
        Write-Host "Ambiente de simulação iniciado com sucesso." -ForegroundColor Green
    } else {
        Write-Warning "Execução concluída com falhas nos passos: $($failures -join ', ')."
    }

    if ($RestoreDisplayOnLauncherExit) {
        Wait-ForLauncherExit
    }
} finally {
    Restore-DesktopDisplay
}
