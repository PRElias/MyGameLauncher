namespace MyGameLauncher;

internal sealed class MainForm : Form
{
    private readonly Button simRacingButton = new();
    private readonly Button streamingButton = new();
    private readonly Button desktopButton = new();
    private readonly TextBox logBox = new();
    private readonly Label statusLabel = new();
    private readonly LauncherActions actions;
    private CancellationTokenSource? currentAction;

    public MainForm()
    {
        actions = new LauncherActions(Log);
        InitializeWindow();
    }

    private void InitializeWindow()
    {
        Text = "MyGameLauncher";
        StartPosition = FormStartPosition.CenterScreen;
        MinimumSize = new Size(560, 430);
        Size = new Size(680, 500);
        BackColor = Color.FromArgb(22, 26, 31);
        ForeColor = Color.White;
        Font = new Font("Segoe UI", 10F);

        var sourceIconPath = Path.GetFullPath(Path.Combine(AppContext.BaseDirectory, @"..\..\..\..\assets\MyGameLauncher.ico"));
        if (File.Exists(sourceIconPath))
        {
            Icon = new Icon(sourceIconPath);
        }
        else
        {
            Icon = Icon.ExtractAssociatedIcon(Application.ExecutablePath);
        }

        var root = new TableLayoutPanel
        {
            Dock = DockStyle.Fill,
            Padding = new Padding(20),
            ColumnCount = 1,
            RowCount = 4
        };
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));
        root.RowStyles.Add(new RowStyle(SizeType.Absolute, 16));
        root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        root.RowStyles.Add(new RowStyle(SizeType.AutoSize));

        var buttons = new TableLayoutPanel
        {
            Dock = DockStyle.Top,
            ColumnCount = 3,
            RowCount = 1,
            Height = 88
        };
        buttons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.333F));
        buttons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.333F));
        buttons.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 33.333F));

        ConfigureButton(simRacingButton, "Simracing", Color.FromArgb(226, 48, 58));
        ConfigureButton(streamingButton, "Streaming", Color.FromArgb(0, 150, 190));
        ConfigureButton(desktopButton, "Desktop", Color.FromArgb(92, 106, 116));

        simRacingButton.Click += async (_, _) => await RunActionAsync("Simracing", actions.RunSimRacingAsync);
        streamingButton.Click += async (_, _) => await RunActionAsync("Streaming", _ => actions.RunStreamingAsync());
        desktopButton.Click += async (_, _) => await RunActionAsync("Desktop", _ => actions.RunDesktopAsync());

        buttons.Controls.Add(simRacingButton, 0, 0);
        buttons.Controls.Add(streamingButton, 1, 0);
        buttons.Controls.Add(desktopButton, 2, 0);

        logBox.Dock = DockStyle.Fill;
        logBox.Multiline = true;
        logBox.ReadOnly = true;
        logBox.ScrollBars = ScrollBars.Vertical;
        logBox.BackColor = Color.FromArgb(13, 16, 20);
        logBox.ForeColor = Color.FromArgb(232, 238, 241);
        logBox.BorderStyle = BorderStyle.FixedSingle;
        logBox.Font = new Font("Consolas", 9.5F);

        statusLabel.AutoSize = false;
        statusLabel.Height = 28;
        statusLabel.Dock = DockStyle.Bottom;
        statusLabel.TextAlign = ContentAlignment.MiddleLeft;
        statusLabel.ForeColor = Color.FromArgb(180, 190, 198);
        statusLabel.Text = "Pronto";

        root.Controls.Add(buttons, 0, 0);
        root.Controls.Add(logBox, 0, 2);
        root.Controls.Add(statusLabel, 0, 3);
        Controls.Add(root);
    }

    private static void ConfigureButton(Button button, string text, Color accent)
    {
        button.Dock = DockStyle.Fill;
        button.Margin = new Padding(0, 0, 12, 0);
        button.Text = text;
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 0;
        button.BackColor = accent;
        button.ForeColor = Color.White;
        button.Font = new Font("Segoe UI Semibold", 12F, FontStyle.Bold);
        button.Cursor = Cursors.Hand;
        button.UseVisualStyleBackColor = false;
    }

    private async Task RunActionAsync(string name, Func<CancellationToken, Task> action)
    {
        if (currentAction is not null)
        {
            return;
        }

        currentAction = new CancellationTokenSource();
        SetBusy(true, $"{name} em execucao...");

        try
        {
            await action(currentAction.Token);
            statusLabel.Text = $"{name} concluido";
        }
        catch (OperationCanceledException)
        {
            statusLabel.Text = $"{name} cancelado";
            Log($"{name} cancelado.");
        }
        catch (Exception ex)
        {
            statusLabel.Text = $"{name} falhou";
            Log($"Erro - {ex.Message}");
        }
        finally
        {
            currentAction.Dispose();
            currentAction = null;
            SetBusy(false, statusLabel.Text);
        }
    }

    private void SetBusy(bool busy, string status)
    {
        simRacingButton.Enabled = !busy;
        streamingButton.Enabled = !busy;
        desktopButton.Enabled = !busy;
        statusLabel.Text = status;
    }

    private void Log(string message)
    {
        if (InvokeRequired)
        {
            BeginInvoke(() => Log(message));
            return;
        }

        logBox.AppendText($"[{DateTime.Now:HH:mm:ss}] {message}{Environment.NewLine}");
    }

    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        currentAction?.Cancel();
        base.OnFormClosing(e);
    }
}
