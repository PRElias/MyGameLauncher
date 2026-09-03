using System.Diagnostics;
using System.Runtime.InteropServices;

namespace SimRacingLauncher;

internal static class BorderlessWindow
{
    private const int GwlStyle = -16;
    private const int WsCaption = 0x00C00000;
    private const int WsThickFrame = 0x00040000;
    private const uint SwpFrameChanged = 0x0020;
    private const uint SwpShowWindow = 0x0040;

    public static bool ApplyToIRacing(Action<string> log)
    {
        var process = Process.GetProcessesByName("iRacingSim64DX11")
            .FirstOrDefault(item => item.MainWindowHandle != IntPtr.Zero);

        if (process is null)
        {
            log("Processo do iRacing nao encontrado ou a janela ainda nao carregou.");
            return false;
        }

        var bounds = Screen.PrimaryScreen?.Bounds ?? new Rectangle(0, 0, 2560, 1440);
        var style = GetWindowLong(process.MainWindowHandle, GwlStyle);
        style &= ~(WsCaption | WsThickFrame);

        SetWindowLong(process.MainWindowHandle, GwlStyle, style);
        SetWindowPos(process.MainWindowHandle, IntPtr.Zero, 0, 0, bounds.Width, bounds.Height, SwpFrameChanged | SwpShowWindow);

        log($"Janela do iRacing ajustada para borderless ({bounds.Width} x {bounds.Height}).");
        return true;
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern int GetWindowLong(IntPtr hWnd, int nIndex);

    [DllImport("user32.dll")]
    private static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int x, int y, int cx, int cy, uint uFlags);
}
