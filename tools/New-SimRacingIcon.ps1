param(
    [string]$OutputPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\SimRacingLauncher.ico')
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing
if (-not ([System.Management.Automation.PSTypeName]'NativeIconMethods').Type) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class NativeIconMethods {
    [DllImport("user32.dll", SetLastError = true)]
    public static extern bool DestroyIcon(IntPtr hIcon);
}
"@
}

function New-IconBitmap {
    param([int]$Size)

    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $graphics.Clear([System.Drawing.Color]::Transparent)

    $scale = $Size / 256.0
    function S([float]$value) { return [float]($value * $scale) }

    $bounds = [System.Drawing.RectangleF]::new((S 12), (S 12), (S 232), (S 232))
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $radius = S 46
    $diameter = $radius * 2
    $path.AddArc($bounds.X, $bounds.Y, $diameter, $diameter, 180, 90)
    $path.AddArc($bounds.Right - $diameter, $bounds.Y, $diameter, $diameter, 270, 90)
    $path.AddArc($bounds.Right - $diameter, $bounds.Bottom - $diameter, $diameter, $diameter, 0, 90)
    $path.AddArc($bounds.X, $bounds.Bottom - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()

    $background = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $bounds,
        [System.Drawing.Color]::FromArgb(255, 18, 22, 28),
        [System.Drawing.Color]::FromArgb(255, 45, 52, 58),
        45
    )
    $graphics.FillPath($background, $path)

    $stripePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 236, 55, 62), (S 24))
    $stripePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $stripePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($stripePen, (S 62), (S 194), (S 192), (S 64))

    $cyanPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 0, 202, 255), (S 12))
    $cyanPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $cyanPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawArc($cyanPen, (S 42), (S 42), (S 172), (S 172), 206, 238)

    $wheelRect = [System.Drawing.RectangleF]::new((S 62), (S 68), (S 132), (S 132))
    $wheelBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        $wheelRect,
        [System.Drawing.Color]::FromArgb(255, 238, 244, 247),
        [System.Drawing.Color]::FromArgb(255, 108, 120, 130),
        90
    )
    $graphics.FillEllipse($wheelBrush, $wheelRect)
    $graphics.FillEllipse([System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 28, 32, 38)), (S 82), (S 88), (S 92), (S 92))

    $hubBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 238, 244, 247))
    $graphics.FillEllipse($hubBrush, (S 112), (S 118), (S 32), (S 32))

    $spokePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 238, 244, 247), (S 12))
    $spokePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $spokePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawLine($spokePen, (S 128), (S 134), (S 128), (S 93))
    $graphics.DrawLine($spokePen, (S 128), (S 134), (S 93), (S 161))
    $graphics.DrawLine($spokePen, (S 128), (S 134), (S 163), (S 161))

    $shinePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(160, 255, 255, 255), (S 8))
    $shinePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $shinePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawArc($shinePen, (S 68), (S 70), (S 118), (S 118), 210, 75)

    $borderPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(210, 255, 255, 255), (S 5))
    $graphics.DrawPath($borderPen, $path)

    $graphics.Dispose()
    return $bitmap
}

function Save-BitmapAsIconImageBytes {
    param([System.Drawing.Bitmap]$Bitmap)

    $stream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.BinaryWriter]::new($stream)
    $width = $Bitmap.Width
    $height = $Bitmap.Height
    $xorStride = $width * 4
    $andStride = [int]([Math]::Ceiling($width / 32.0) * 4)

    $writer.Write([UInt32]40)
    $writer.Write([Int32]$width)
    $writer.Write([Int32]($height * 2))
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]32)
    $writer.Write([UInt32]0)
    $writer.Write([UInt32]($xorStride * $height))
    $writer.Write([Int32]0)
    $writer.Write([Int32]0)
    $writer.Write([UInt32]0)
    $writer.Write([UInt32]0)

    for ($y = $height - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $width; $x++) {
            $pixel = $Bitmap.GetPixel($x, $y)
            $writer.Write([byte]$pixel.B)
            $writer.Write([byte]$pixel.G)
            $writer.Write([byte]$pixel.R)
            $writer.Write([byte]$pixel.A)
        }
    }

    $emptyMaskRow = [byte[]]::new($andStride)
    for ($y = 0; $y -lt $height; $y++) {
        $writer.Write($emptyMaskRow)
    }

    $writer.Flush()
    return $stream.ToArray()
}

$outputDirectory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
    New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}

$bitmap = New-IconBitmap -Size 256
$iconHandle = $bitmap.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($iconHandle)
$file = [System.IO.File]::Open($OutputPath, [System.IO.FileMode]::Create)
try {
    $icon.Save($file)
} finally {
    $file.Dispose()
    $icon.Dispose()
    $bitmap.Dispose()
    [NativeIconMethods]::DestroyIcon($iconHandle) | Out-Null
}

Write-Host "Icone gerado: $OutputPath"
