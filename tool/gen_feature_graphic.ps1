# Generates a 1024x500 Play Store Feature Graphic with left logo and right title
param(
  [int]$Width = 1024,
  [int]$Height = 500,
  [string]$BackgroundSolid = "#F7F9FC",     # very light neutral
  [string]$AccentBlue = "#1976D2",          # calming blue
  [switch]$UseGradient,                      # if set, overlay subtle diagonal blue gradient
  [switch]$UseRadial,                        # if set, use radial gradient background
  [string]$RadialCenterHex = "#F8FAFC",
  [string]$RadialEdgeHex = "#F0F6FF",
  [string]$Title = "KinCircle",
  [string]$TitleColor = "#0F172A",
  [string]$PrimaryFont = "Inter",           # will fallback if not available
  [string]$FallbackFont = "Segoe UI",
  [int]$LeftMargin = 64,
  [int]$RightMargin = 64,
  [int]$TopBottomMargin = 64,
  [int]$LogoDiameter = 360,
  [string]$LogoPath = "assets/icon/kincircle_logo_ring_512_v6.png",
  [string]$Tagline = "Peace of mind, powered by AI.",
  [string]$TaglineColor = "#64748B",
  [string]$OutDir = "assets/marketing",
  [string]$FileName = "feature_graphic_1024x500.png"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Convert-HexToColor {
  param([Parameter(Mandatory)][string]$Hex)
  $hexClean = $Hex.Trim().TrimStart('#')
  if ($hexClean.Length -eq 6) {
    $a = 255; $r = [Convert]::ToInt32($hexClean.Substring(0,2),16); $g = [Convert]::ToInt32($hexClean.Substring(2,2),16); $b = [Convert]::ToInt32($hexClean.Substring(4,2),16)
  }
  elseif ($hexClean.Length -eq 8) {
    $a = [Convert]::ToInt32($hexClean.Substring(0,2),16); $r = [Convert]::ToInt32($hexClean.Substring(2,2),16); $g = [Convert]::ToInt32($hexClean.Substring(4,2),16); $b = [Convert]::ToInt32($hexClean.Substring(6,2),16)
  }
  else { throw "Invalid hex color: $Hex" }
  return [System.Drawing.Color]::FromArgb($a,$r,$g,$b)
}

Add-Type -AssemblyName System.Drawing

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $repoRoot $OutDir
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }
$outPath = Join-Path $outputDir $FileName

$bmp = New-Object System.Drawing.Bitmap -ArgumentList @($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gfx.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$gfx.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

# Background
$bg = Convert-HexToColor $BackgroundSolid
$gfx.Clear($bg)
if ($UseRadial) {
  # Radial gradient: center off-white to edge light blue
  $centerCol = Convert-HexToColor $RadialCenterHex
  $edgeCol = Convert-HexToColor $RadialEdgeHex
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $ellipseRect = New-Object System.Drawing.Rectangle 0,0,$Width,$Height
  $path.AddEllipse($ellipseRect)
  $pgb = New-Object System.Drawing.Drawing2D.PathGradientBrush $path
  $pgb.CenterColor = $centerCol
  $pgb.SurroundColors = ,$edgeCol
  $gfx.FillRectangle($pgb, 0,0,$Width,$Height)
  $pgb.Dispose(); $path.Dispose()
}
elseif ($UseGradient) {
  $accent = Convert-HexToColor $AccentBlue
  $cFrom = [System.Drawing.Color]::FromArgb(28, $accent.R, $accent.G, $accent.B)
  $cTo   = [System.Drawing.Color]::FromArgb(0,  $accent.R, $accent.G, $accent.B)
  $rect = New-Object System.Drawing.Rectangle 0,0,$Width,$Height
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $cFrom, $cTo, 45.0
  $gfx.FillRectangle($brush, $rect)
  $brush.Dispose()
}

# Load and place logo on left
$logoFullPath = Join-Path $repoRoot $LogoPath
if (-not (Test-Path $logoFullPath)) { throw "Logo not found at $logoFullPath" }
$logoImg = [System.Drawing.Image]::FromFile($logoFullPath)
# Scale preserving aspect ratio to fit in LogoDiameter square
$ratio = [math]::Min($LogoDiameter / [double]$logoImg.Width, $LogoDiameter / [double]$logoImg.Height)
$destW = [int]([math]::Round($logoImg.Width * $ratio))
$destH = [int]([math]::Round($logoImg.Height * $ratio))
$destX = $LeftMargin
$destY = [int]([math]::Round(($Height - $destH) / 2.0))
$logoRect = New-Object System.Drawing.Rectangle $destX, $destY, $destW, $destH
$gfx.DrawImage($logoImg, $logoRect)
$logoImg.Dispose()

# Title and tagline on the right
$textAreaX = $destX + $destW + 40
$textAreaWidth = $Width - $RightMargin - $textAreaX
$textAreaHeight = $Height - (2 * $TopBottomMargin)
$sf = New-Object System.Drawing.StringFormat
$sf.Alignment = [System.Drawing.StringAlignment]::Near
$sf.LineAlignment = [System.Drawing.StringAlignment]::Near

# Try Inter first; fallback to Segoe UI
$fontSize = 110
$font = $null
try { $font = New-Object System.Drawing.Font -ArgumentList @($PrimaryFont, [single]$fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel) } catch {}
if (-not $font) { $font = New-Object System.Drawing.Font -ArgumentList @($FallbackFont, [single]$fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel) }

# Downscale font to fit width if needed
for ($i=0; $i -lt 12; $i++) {
  $size = $gfx.MeasureString($Title, $font)
  if ($size.Width -le $textAreaWidth -and $size.Height -le $textAreaHeight) { break }
  $font.Dispose(); $fontSize = [math]::Max(48, $fontSize - 8)
  try { $font = New-Object System.Drawing.Font -ArgumentList @($PrimaryFont, [single]$fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel) } catch { $font = New-Object System.Drawing.Font -ArgumentList @($FallbackFont, [single]$fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel) }
}

$textColor = Convert-HexToColor $TitleColor
$brushText = New-Object System.Drawing.SolidBrush $textColor

# Tagline font (smaller, elegant)
$tagColor = Convert-HexToColor $TaglineColor
$brushTag = New-Object System.Drawing.SolidBrush $tagColor
$tagSize = [int]([math]::Max(28, [math]::Round($fontSize * 0.36)))
$tagFont = $null
try { $tagFont = New-Object System.Drawing.Font -ArgumentList @($PrimaryFont, [single]$tagSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel) } catch {}
if (-not $tagFont) { $tagFont = New-Object System.Drawing.Font -ArgumentList @($FallbackFont, [single]$tagSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel) }

# Ensure both lines fit width; downscale if needed together to preserve hierarchy
for ($i=0; $i -lt 12; $i++) {
  $titleMeasure = $gfx.MeasureString($Title, $font)
  $tagMeasure = $gfx.MeasureString($Tagline, $tagFont)
  if ($titleMeasure.Width -le $textAreaWidth -and $tagMeasure.Width -le $textAreaWidth) { break }
  # reduce both sizes proportionally
  $font.Dispose(); $tagFont.Dispose()
  $fontSize = [math]::Max(48, $fontSize - 6)
  $tagSize = [math]::Max(24, $tagSize - 4)
  try { $font = New-Object System.Drawing.Font -ArgumentList @($PrimaryFont, [single]$fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel) } catch { $font = New-Object System.Drawing.Font -ArgumentList @($FallbackFont, [single]$fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel) }
  try { $tagFont = New-Object System.Drawing.Font -ArgumentList @($PrimaryFont, [single]$tagSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel) } catch { $tagFont = New-Object System.Drawing.Font -ArgumentList @($FallbackFont, [single]$tagSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel) }
}

# Vertical layout: center the combined block (title + spacing + tagline)
$titleMeasure = $gfx.MeasureString($Title, $font)
$tagMeasure = $gfx.MeasureString($Tagline, $tagFont)
$lineSpacing = 16
$blockH = $titleMeasure.Height + $lineSpacing + $tagMeasure.Height
$blockTop = [single]([math]::Round(($Height - $blockH) / 2.0))

$titleRect = New-Object System.Drawing.RectangleF $textAreaX, $blockTop, $textAreaWidth, $titleMeasure.Height
$tagRect = New-Object System.Drawing.RectangleF $textAreaX, ($blockTop + $titleMeasure.Height + $lineSpacing), $textAreaWidth, $tagMeasure.Height

$gfx.DrawString($Title, $font, $brushText, $titleRect, $sf)
$gfx.DrawString($Tagline, $tagFont, $brushTag, $tagRect, $sf)

# Cleanup and save
$brushTag.Dispose(); $brushText.Dispose(); $tagFont.Dispose(); $font.Dispose(); $sf.Dispose(); $gfx.Dispose()
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Generated: $outPath"
