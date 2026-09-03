using System.Runtime.InteropServices;

namespace SimRacingLauncher;

internal enum RefreshRateMode
{
    ResolutionOnly,
    Max,
    Specific
}

internal sealed record DisplayRequest(int Width, int Height, RefreshRateMode RefreshRateMode, double? RefreshRate = null)
{
    public static DisplayRequest Max(int width, int height) => new(width, height, RefreshRateMode.Max);

    public static DisplayRequest ResolutionOnly(int width, int height) => new(width, height, RefreshRateMode.ResolutionOnly);

    public static DisplayRequest Specific(int width, int height, double refreshRate) => new(width, height, RefreshRateMode.Specific, refreshRate);
}

internal static class DisplayManager
{
    private const int EnumCurrentSettings = -1;
    private const int DisplayDevicePrimaryDevice = 0x4;
    private const int DmBitsPerPel = 0x40000;
    private const int DmPelsWidth = 0x80000;
    private const int DmPelsHeight = 0x100000;
    private const int DmDisplayFrequency = 0x400000;
    private const int DispChangeSuccessful = 0;

    public static bool Apply(DisplayRequest request, Action<string> log)
    {
        var deviceName = GetPrimaryDeviceName();
        var requestedFrequency = request.RefreshRateMode == RefreshRateMode.Specific
            ? (int)Math.Round(request.RefreshRate!.Value)
            : (int?)null;

        var modes = EnumerateModes(deviceName)
            .Where(mode => mode.dmPelsWidth == request.Width && mode.dmPelsHeight == request.Height)
            .ToList();

        IEnumerable<DEVMODE> modesToTry = request.RefreshRateMode switch
        {
            RefreshRateMode.Max => modes
                .OrderByDescending(mode => mode.dmDisplayFrequency)
                .ThenByDescending(mode => mode.dmBitsPerPel),
            RefreshRateMode.Specific => modes
                .OrderBy(mode => Math.Abs(mode.dmDisplayFrequency - requestedFrequency!.Value))
                .ThenByDescending(mode => mode.dmDisplayFrequency),
            _ => []
        };

        foreach (var mode in modesToTry)
        {
            var modeToTry = mode;
            modeToTry.dmFields = DmBitsPerPel | DmPelsWidth | DmPelsHeight | DmDisplayFrequency;
            log($"Tentando modo: {modeToTry.dmPelsWidth}x{modeToTry.dmPelsHeight} @ {modeToTry.dmDisplayFrequency} Hz");

            var result = ChangeDisplaySettingsEx(deviceName, ref modeToTry, IntPtr.Zero, 0, IntPtr.Zero);
            if (result == DispChangeSuccessful)
            {
                return true;
            }

            var globalResult = ChangeDisplaySettings(ref modeToTry, 0);
            if (globalResult == DispChangeSuccessful)
            {
                return true;
            }

            log($"Modo recusado: {modeToTry.dmPelsWidth}x{modeToTry.dmPelsHeight} @ {modeToTry.dmDisplayFrequency} Hz (codigos {result}/{globalResult}).");
        }

        var directMode = NewDevMode();
        directMode.dmPelsWidth = request.Width;
        directMode.dmPelsHeight = request.Height;
        directMode.dmBitsPerPel = 32;
        directMode.dmFields = DmBitsPerPel | DmPelsWidth | DmPelsHeight;

        if (requestedFrequency.HasValue)
        {
            directMode.dmDisplayFrequency = requestedFrequency.Value;
            directMode.dmFields |= DmDisplayFrequency;
        }

        log(modes.Count == 0
            ? $"Nenhum modo enumerado para {request.Width}x{request.Height}. Tentando alteracao direta."
            : $"Todos os modos enumerados para {request.Width}x{request.Height} foram recusados. Tentando alteracao direta.");

        var directResult = ChangeDisplaySettingsEx(deviceName, ref directMode, IntPtr.Zero, 0, IntPtr.Zero);
        if (directResult == DispChangeSuccessful)
        {
            return true;
        }

        var directGlobalResult = ChangeDisplaySettings(ref directMode, 0);
        if (directGlobalResult == DispChangeSuccessful)
        {
            return true;
        }

        if (requestedFrequency.HasValue)
        {
            log($"Alteracao direta com frequencia recusada (codigos {directResult}/{directGlobalResult}). Tentando apenas resolucao.");
            return Apply(DisplayRequest.ResolutionOnly(request.Width, request.Height), log);
        }

        log($"Windows recusou a alteracao (codigos {directResult}/{directGlobalResult}).");
        return false;
    }

    private static string? GetPrimaryDeviceName()
    {
        for (var index = 0; ; index++)
        {
            var device = NewDisplayDevice();
            if (!EnumDisplayDevices(null, index, ref device, 0))
            {
                return null;
            }

            if ((device.StateFlags & DisplayDevicePrimaryDevice) != 0)
            {
                return device.DeviceName;
            }
        }
    }

    private static IEnumerable<DEVMODE> EnumerateModes(string? deviceName)
    {
        for (var index = 0; ; index++)
        {
            var mode = NewDevMode();
            if (!EnumDisplaySettings(deviceName, index, ref mode))
            {
                yield break;
            }

            yield return mode;
        }
    }

    private static DEVMODE NewDevMode()
    {
        var mode = new DEVMODE();
        mode.dmSize = (short)Marshal.SizeOf<DEVMODE>();
        return mode;
    }

    private static DISPLAY_DEVICE NewDisplayDevice()
    {
        var device = new DISPLAY_DEVICE();
        device.cb = Marshal.SizeOf<DISPLAY_DEVICE>();
        return device;
    }

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    private static extern bool EnumDisplayDevices(string? lpDevice, int iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, int dwFlags);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    private static extern bool EnumDisplaySettings(string? deviceName, int modeNum, ref DEVMODE devMode);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    private static extern int ChangeDisplaySettings(ref DEVMODE devMode, int flags);

    [DllImport("user32.dll", CharSet = CharSet.Ansi)]
    private static extern int ChangeDisplaySettingsEx(string? deviceName, ref DEVMODE devMode, IntPtr hwnd, int flags, IntPtr lParam);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    private struct DISPLAY_DEVICE
    {
        public int cb;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
        public int StateFlags;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Ansi)]
    private struct DEVMODE
    {
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
        public short dmSpecVersion;
        public short dmDriverVersion;
        public short dmSize;
        public short dmDriverExtra;
        public int dmFields;
        public int dmPositionX;
        public int dmPositionY;
        public int dmDisplayOrientation;
        public int dmDisplayFixedOutput;
        public short dmColor;
        public short dmDuplex;
        public short dmYResolution;
        public short dmTTOption;
        public short dmCollate;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
        public short dmLogPixels;
        public int dmBitsPerPel;
        public int dmPelsWidth;
        public int dmPelsHeight;
        public int dmDisplayFlags;
        public int dmDisplayFrequency;
    }
}
