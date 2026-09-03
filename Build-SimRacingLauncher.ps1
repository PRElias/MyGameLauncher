$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$source = Join-Path $root 'Simracing.ps1'
$output = Join-Path $root 'SimRacingLauncher.exe'
$icon = Join-Path $root 'assets\SimRacingLauncher.ico'
$localPs2Exe = Join-Path $root 'tools\ps2exe\1.0.18\ps2exe.psd1'

if (-not (Test-Path -LiteralPath $source)) {
    throw "Arquivo fonte nao encontrado: $source"
}

if (-not (Test-Path -LiteralPath $icon)) {
    & (Join-Path $root 'tools\New-SimRacingIcon.ps1') -OutputPath $icon
}

if (Test-Path -LiteralPath $localPs2Exe) {
    Import-Module $localPs2Exe -Force
} elseif (Get-Module -ListAvailable ps2exe) {
    Import-Module ps2exe -Force
} else {
    throw "ps2exe nao encontrado. Instale com: Install-Module -Name ps2exe -Scope CurrentUser"
}

Invoke-ps2exe `
    -inputFile $source `
    -outputFile $output `
    -iconFile $icon `
    -requireAdmin `
    -x64 `
    -title 'SimRacing Launcher' `
    -description 'Inicializador do ambiente de simulacao' `
    -product 'SimRacing Launcher' `
    -version '1.0.0.0' `
    -ErrorAction Stop

if (-not (Test-Path -LiteralPath $output)) {
    throw "O executavel nao foi gerado: $output"
}

Write-Host "Executavel gerado: $output"
