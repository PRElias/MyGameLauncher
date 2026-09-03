# Caminhos configuráveis. Ajuste apenas os valores que forem diferentes no seu PC.
$OutputEncoding = [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$SteamVR = "steam://rungameid/250820"
$OBS = "C:\Program Files\obs-studio\bin\64bit\obs64.exe"
$CrewChiefCandidates = "C:\Program Files (x86)\Britton IT Ltd\CrewChiefV4\CrewChiefV4.exe"
$TradingPaints = "C:\Program Files (x86)\Rhinode LLC\Trading Paints\Trading Paints.exe"
$Discord = "$env:LocalAppData\Discord\Update.exe"
$iRacing = "C:\Program Files (x86)\iRacing\ui\iRacingUI.exe"
$ForceBorderless = Join-Path $PSScriptRoot "ForceBorderless.ps1"

$failures = [System.Collections.Generic.List[string]]::new()

function Set-ScreenResolution {
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
        [DllImport("user32.dll", CharSet = CharSet.Ansi)]
        public static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);
        public const int DM_PELSWIDTH = 0x80000, DM_PELSHEIGHT = 0x100000;
        public const int DISP_CHANGE_SUCCESSFUL = 0;
    }
}
"@
    }

    $mode = New-Object Display.NativeMethods+DEVMODE
    $mode.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf($mode)
    $mode.dmPelsWidth = 2560
    $mode.dmPelsHeight = 1440
    $mode.dmFields = [Display.NativeMethods]::DM_PELSWIDTH -bor [Display.NativeMethods]::DM_PELSHEIGHT
    return [Display.NativeMethods]::ChangeDisplaySettings([ref]$mode, 0) -eq [Display.NativeMethods]::DISP_CHANGE_SUCCESSFUL
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
                if (-not (Test-Path -LiteralPath $ForceBorderless)) {
                    throw "Arquivo nao encontrado: $ForceBorderless"
                }
                & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $ForceBorderless
                if ($LASTEXITCODE -ne 0) { throw "O script ForceBorderless.ps1 terminou com erro." }
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

Stop-BackgroundApplications

Write-Host "Iniciando ambiente de simulação..." -ForegroundColor Cyan

Write-Host "1. Alterando resolução para 2560x1440..."
try {
    if (-not (Set-ScreenResolution)) { throw "O Windows recusou a alteração de resolução." }
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
