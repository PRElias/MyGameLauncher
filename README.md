# SimRacing Launcher

Inicializador Windows para preparar o ambiente de sim racing:

- ajusta a resolucao para `2560x1440`;
- mantem/forca a frequencia configurada em `Simracing.ps1`;
- fecha apps e servicos de fundo definidos no script;
- inicia SteamVR, CrewChief, Discord, Trading Paints, OBS e iRacing;
- aplica modo borderless na janela do iRacing quando ela aparecer.

## Executar

Use o arquivo:

```text
SimRacingLauncher.exe
```

O executavel foi gerado com manifesto `requireAdmin`, entao o Windows deve abrir o prompt do UAC automaticamente ao iniciar.

## Posso copiar apenas o executavel para outra maquina?

Sim. Para executar na maquina destino, em geral basta copiar apenas:

```text
SimRacingLauncher.exe
```

O icone e o conteudo do `Simracing.ps1` ficam embutidos no executavel. A maquina destino nao precisa ter `ps2exe` instalado e tambem nao precisa receber a pasta `tools`.

Mas a maquina destino ainda precisa ter os programas nos caminhos configurados dentro do script, por exemplo OBS, CrewChief, Trading Paints e iRacing. Se os caminhos forem diferentes, ajuste `Simracing.ps1` neste projeto e gere o executavel novamente.

## Gerar o executavel

Para regenerar o launcher a partir do script:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Build-SimRacingLauncher.ps1
```

Esse comando gera/atualiza:

```text
SimRacingLauncher.exe
```

O build usa o `ps2exe` versionado no projeto em:

```text
tools\ps2exe\1.0.18
```

Assim, nao e necessario instalar `ps2exe` globalmente para compilar em outra maquina que tenha o repositório completo.

## Icone

O icone final fica em:

```text
assets\SimRacingLauncher.ico
```

Para regenerar somente o icone:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\tools\New-SimRacingIcon.ps1
```

Ao rodar `Build-SimRacingLauncher.ps1`, esse icone e embutido no executavel.

## Resolucao e frequencia

As configuracoes ficam no inicio de `Simracing.ps1`:

```powershell
$TargetWidth = 2560
$TargetHeight = 1440
$TargetRefreshRate = 174.96
```

Quando `$TargetRefreshRate` tem valor, o launcher informa essa frequencia ao Windows junto com a resolucao. O valor e arredondado para a API do Windows, entao `174.96` e enviado como `175`.

Se `$TargetRefreshRate` estiver `$null`, o launcher tenta ler a frequencia atual do monitor e manter esse valor. Se essa leitura falhar em alguma maquina, ele mostra um aviso e altera apenas a resolucao, como o script original fazia.

## Arquivos principais

- `Simracing.ps1`: fonte principal do launcher.
- `SimRacingLauncher.exe`: executavel pronto para uso.
- `Build-SimRacingLauncher.ps1`: script de build.
- `assets\SimRacingLauncher.ico`: icone do executavel.
- `tools\ps2exe\1.0.18`: dependencia local usada apenas para gerar o `.exe`.
