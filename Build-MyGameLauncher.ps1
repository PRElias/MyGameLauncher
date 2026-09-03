$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$project = Join-Path $root 'src\MyGameLauncher\MyGameLauncher.csproj'
$publishDir = Join-Path $root 'publish\MyGameLauncher'

dotnet publish $project `
    --configuration Release `
    --runtime win-x64 `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -p:EnableCompressionInSingleFile=true `
    -p:DebugType=None `
    -p:DebugSymbols=false `
    --output $publishDir

if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish falhou com codigo $LASTEXITCODE."
}

Write-Host "Executavel publicado em: $publishDir"
