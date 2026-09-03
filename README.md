# MyGameLauncher

Launcher Windows em .NET para alternar rapidamente entre modos de tela e iniciar o ambiente de sim racing.

Esta branch contem a versao atual com interface grafica. A branch `simracing` preserva a versao anterior baseada em PowerShell/ps2exe.

## Botoes

### Simracing

Executa o fluxo completo:

- altera a tela para `2560x1440` usando a maior frequencia disponivel;
- fecha apps e servicos de fundo definidos no codigo;
- inicia SteamVR, CrewChief, Discord, Trading Paints, OBS e iRacing.

### Streaming

Executa apenas a parte de resolucao:

- altera a tela para `2560x1440` usando a maior frequencia disponivel;
- nao fecha processos;
- nao para servicos;
- nao abre programas.

### Desktop

Restaura a tela para o modo de desktop:

- `3440x1440` usando a maior frequencia disponivel.

### Borderless

Aplica modo borderless na janela atual do iRacing:

- nao altera resolucao;
- nao abre nem fecha programas;
- use depois que a sessao do iRacing ja estiver carregada.

## Executavel publicado

O executavel pronto para copiar fica em:

```text
publish\MyGameLauncher\MyGameLauncher.exe
```

Ele e publicado como single-file self-contained para `win-x64`, entao pode ser copiado sozinho para a maquina destino. Nao e necessario instalar .NET na maquina destino.

O app tem manifesto `requireAdministrator`, entao o Windows deve pedir permissao de administrador pelo UAC ao abrir.

## Gerar o executavel .NET

Para compilar e publicar:

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\Build-MyGameLauncher.ps1
```

Esse comando atualiza:

```text
publish\MyGameLauncher\MyGameLauncher.exe
```

## Configuracoes principais

As configuracoes ficam em:

```text
src\MyGameLauncher\LauncherActions.cs
```

Valores atuais:

```csharp
private static readonly DisplayRequest SimRacingDisplay = DisplayRequest.Max(2560, 1440);
private static readonly DisplayRequest DesktopDisplay = DisplayRequest.Max(3440, 1440);
```

`DisplayRequest.Max` enumera os modos anunciados pelo monitor/driver para aquela resolucao e tenta usar a maior frequencia disponivel. Se o Windows recusar um modo, o launcher tenta os proximos modos. Se todos forem recusados, ele cai em uma alteracao direta de resolucao como fallback.

## Observacao sobre taxa dinamica

O launcher nao altera diretamente a opcao de taxa de atualizacao dinamica do Windows. Essa configuracao depende do Windows/driver/monitor e nao tem uma API simples e confiavel como a troca de resolucao/frequencia.

O objetivo do app e aplicar explicitamente a resolucao desejada e escolher o melhor refresh rate anunciado pelo driver para essa resolucao.

## Arquivos principais

- `src\MyGameLauncher`: projeto WinForms .NET.
- `Build-MyGameLauncher.ps1`: publica o executavel self-contained.
- `publish\MyGameLauncher\MyGameLauncher.exe`: executavel pronto para uso.
- `assets\MyGameLauncher.ico`: icone do app.
