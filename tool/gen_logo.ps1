# Requires: Windows PowerShell 5.1+ (System.Drawing from .NET Framework)
param(
    [int]$Size = 512,
    [string]$PrimaryHex = "#2166F3",   # Primary gradient color (start)
    [string]$SecondaryHex = "#1A73E8", # Secondary gradient color (end)
    [string]$Text = "KC",
    [string]$FontFamily = "Segoe UI",
    [int]$FontSize = 220,
    [string]$OutDir = "assets/icon",
    [string]$FileName = "kincircle_logo_512.png"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-HexToColor {
    param([Parameter(Mandatory)][string]$Hex)
    $hexClean = $Hex.Trim().TrimStart('#')
    if ($hexClean.Length -eq 6) { $a = 255; $r = [Convert]::ToInt32($hexClean.Substring(0,2),16); $g = [Convert]::ToInt32($hexClean.Substring(2,2),16); $b = [Convert]::ToInt32($hexClean.Substring(4,2),16) }
    elseif ($hexClean.Length -eq 8) { $a = [Convert]::ToInt32($hexClean.Substring(0,2),16); $r = [Convert]::ToInt32($hexClean.Substring(2,2),16); $g = [Convert]::ToInt32($hexClean.Substring(4,2),16); $b = [Convert]::ToInt32($hexClean.Substring(6,2),16) }
    else { throw "Invalid hex color: $Hex" }
    return [System.Drawing.Color]::FromArgb($a,$r,$g,$b)
}

Add-Type -AssemblyName System.Drawing

# Resolve paths
$repoRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $repoRoot $OutDir
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }
$outPathMain = Join-Path $outputDir $FileName
$outPathAlias = Join-Path $outputDir "kincircle_icon_foreground.png"  # Helpful alias for launcher configs

# Prepare drawing surface
$bmp = New-Object System.Drawing.Bitmap $Size, $Size
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gfx.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

$rect = New-Object System.Drawing.Rectangle 0,0,$Size,$Size

# Background gradient
$c1 = Convert-HexToColor $PrimaryHex
$c2 = Convert-HexToColor $SecondaryHex
$angle = 45
$lgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $c1, $c2, $angle
$gfx.FillRectangle($lgBrush, $rect)

# Optional subtle inner circle for depth
$margin = [int]([math]::Round($Size * 0.06))
$innerRect = New-Object System.Drawing.Rectangle $margin,$margin,($Size-2*$margin),($Size-2*$margin)
$innerColor = [System.Drawing.Color]::FromArgb(20, 255, 255, 255) # ~8% white overlay
$innerBrush = New-Object System.Drawing.SolidBrush $innerColor
$gfx.FillEllipse($innerBrush, $innerRect)

# Centered text (KC)
# Build font with explicit -ArgumentList and typed parameters to avoid enum parsing issues
$fontStyle = [System.Drawing.FontStyle]::Bold
$graphicsUnit = [System.Drawing.GraphicsUnit]::Pixel
$font = New-Object System.Drawing.Font -ArgumentList @($FontFamily, [single]$FontSize, $fontStyle, $graphicsUnit)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Center
$sf.LineAlignment = [System.Drawing.StringAlignment]::Center
$textRect = New-Object System.Drawing.RectangleF 0,0,$Size,$Size

# Draw subtle shadow
$shadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(80, 0,0,0))
$gfx.DrawString($Text, $font, $shadowBrush, (New-Object System.Drawing.RectangleF 3,5,$Size,$Size), $sf)

# Draw main text in white
$textBrush = [System.Drawing.Brushes]::White
$gfx.DrawString($Text, $font, $textBrush, $textRect, $sf)

# Save files
$bmp.Save($outPathMain, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save($outPathAlias, [System.Drawing.Imaging.ImageFormat]::Png)

# Cleanup
$lgBrush.Dispose(); $innerBrush.Dispose(); $gfx.Dispose(); $bmp.Dispose()

Write-Host "Generated: $outPathMain"
Write-Host "Alias:     $outPathAlias"
