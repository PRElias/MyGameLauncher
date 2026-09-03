# Silencia erros de re-compilacao se o tipo ja existir na memoria
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

# Busca o processo do iRacing
$process = Get-Process -Name "iRacingSim64DX11" -ErrorAction SilentlyContinue

if ($process -and $process.MainWindowHandle -ne [IntPtr]::Zero) {
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
    [Win32]::SetWindowLong($hwnd, $GWL_STYLE, $style)

    [Win32]::SetWindowPos($hwnd, [IntPtr]::Zero, 0, 0, $width, $height, ($SWP_FRAMECHANGED -bor $SWP_SHOWWINDOW))

    Write-Host "Sucesso! Janela do iRacing ajustada para Borderless ($width x $height)." -ForegroundColor Green
} else {
    Write-Host "Processo do iRacing nao encontrado ou a janela ainda nao carregou." -ForegroundColor Red
}