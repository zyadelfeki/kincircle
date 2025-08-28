# Generates a 512x512 PNG with white background, blue circular border, and a smaller Flutter-style mark
param(
  [int]$Size = 512,
  [int]$RingThickness = 22,
  [string]$RingColor = "#1A73E8",
  [string]$LightBlue = "#44D1FD",
  [string]$DarkBlue = "#2A73FF",
  [float]$Scale = 0.86,               # overall scale of inner logo vs canvas (0..1)
  [string]$InnerImagePath = "",      # optional path to an image to center inside
  [float]$OffsetX = 0.0,              # manual nudge X (pixels after scaling)
  [float]$OffsetY = 0.0,              # manual nudge Y (pixels after scaling)
  [string]$OutDir = "assets/icon",
  [string]$FileName = "kincircle_logo_ring_512.png"
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

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputDir = Join-Path $repoRoot $OutDir
if (-not (Test-Path $outputDir)) { New-Item -ItemType Directory -Path $outputDir | Out-Null }
$outPath = Join-Path $outputDir $FileName

$bmp = New-Object System.Drawing.Bitmap $Size, $Size
$gfx = [System.Drawing.Graphics]::FromImage($bmp)
$gfx.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$gfx.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gfx.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# White background
# Transparent background outside the circle
$gfx.Clear([System.Drawing.Color]::Transparent)

# Blue circular border (ring)
$ringCol = Convert-HexToColor $RingColor
$pen = New-Object System.Drawing.Pen $ringCol, $RingThickness
$margin = [int]([math]::Ceiling($RingThickness/2))
$ringRect = New-Object System.Drawing.Rectangle $margin, $margin, ($Size - 2*$margin), ($Size - 2*$margin)
$gfx.DrawEllipse($pen, $ringRect)

# Fill inner circle with white so the badge is always a solid disc
$innerFillMargin = $margin + [int]([math]::Ceiling($RingThickness/2))
$innerRect = New-Object System.Drawing.Rectangle $innerFillMargin, $innerFillMargin, ($Size - 2*$innerFillMargin), ($Size - 2*$innerFillMargin)
$gfx.FillEllipse([System.Drawing.Brushes]::White, $innerRect)

# If an inner image is provided, center and draw it; otherwise draw a Flutter-style mark
$light = Convert-HexToColor $LightBlue
$dark  = Convert-HexToColor $DarkBlue

function New-ParaPath {
  param([float]$cx, [float]$cy, [float]$w, [float]$h, [float]$deg, [float]$skewX)
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $rect = New-Object System.Drawing.RectangleF (-$w/2), (-$h/2), $w, $h
  $path.AddRectangle($rect)
  $mx = New-Object System.Drawing.Drawing2D.Matrix
  # Shear to create a parallelogram (skew along X)
  $mx.Shear($skewX, 0.0)
  # Rotate around origin then translate to center
  $mx.RotateAt($deg, (New-Object System.Drawing.PointF 0,0))
  $mx.Translate($cx, $cy)
  $path.Transform($mx)
  $mx.Dispose()
  return $path
}

# Scale factors and positions
$centerX = $Size / 2.0
$centerY = $Size / 2.0

# Safe drawable radius (keep away from ring)
$safeMargin = [math]::Max($RingThickness * 1.8, $Size * 0.10)

if ([string]::IsNullOrWhiteSpace($InnerImagePath) -or -not (Test-Path $InnerImagePath)) {
  # Fallback: draw stylized Flutter-like mark
  $unit = ($Size - (2 * $safeMargin)) * $Scale
  # Proportions tuned to resemble Flutter mark
  $angle = -36.0
  # Upper bar (light)
  $bigW = $unit * 0.98
  $bigH = $unit * 0.16
  $bigCx = $centerX - ($unit * 0.12)
  $bigCy = $centerY - ($unit * 0.14)
  $bigSkew = -0.35
  $pathBig = New-ParaPath -cx $bigCx -cy $bigCy -w $bigW -h $bigH -deg $angle -skewX $bigSkew
  $brushLight = New-Object System.Drawing.SolidBrush $light
  $gfx.FillPath($brushLight, $pathBig)
  # Lower bar (dark)
  $smallW = $unit * 0.58
  $smallH = $unit * 0.16
  $smallCx = $centerX + ($unit * 0.18)
  $smallCy = $centerY + ($unit * 0.25)
  $smallSkew = -0.35
  $pathSmall = New-ParaPath -cx $smallCx -cy $smallCy -w $smallW -h $smallH -deg $angle -skewX $smallSkew
  $brushDark = New-Object System.Drawing.SolidBrush $dark
  $gfx.FillPath($brushDark, $pathSmall)
  $brushLight.Dispose(); $brushDark.Dispose(); $pathBig.Dispose(); $pathSmall.Dispose();
}
else {
  # Use provided image exactly, centered and scaled
  $img = [System.Drawing.Image]::FromFile($InnerImagePath)
  # Available area is the inner white disc minus a small padding to avoid touching ring
  $padding = [int]([math]::Ceiling($RingThickness * 0.35))
  $avail = $innerRect.Width - (2 * $padding)
  if ($avail -lt 1) { $avail = [int]([math]::Max(1, $innerRect.Width * 0.9)) }
  $targetMax = [int]([math]::Round($avail * $Scale))
  $ratio = [math]::Min($targetMax / [double]$img.Width, $targetMax / [double]$img.Height)
  $destW = [int]([math]::Round($img.Width * $ratio))
  $destH = [int]([math]::Round($img.Height * $ratio))
  
  # Compute alpha-weighted centroid of the source image to align visually
  $ax = 0.0; $ay = 0.0; $asum = 0.0
  for ($yy = 0; $yy -lt $img.Height; $yy++) {
    for ($xx = 0; $xx -lt $img.Width; $xx++) {
      $c = $img.GetPixel($xx, $yy)
      if ($c.A -gt 0) { $a = [double]$c.A; $ax += $a * $xx; $ay += $a * $yy; $asum += $a }
    }
  }
  if ($asum -gt 0) { $cxSrc = $ax / $asum; $cySrc = $ay / $asum } else { $cxSrc = $img.Width/2.0; $cySrc = $img.Height/2.0 }
  # Scaled centroid in destination space
  $cxScaled = $cxSrc * $ratio
  $cyScaled = $cySrc * $ratio
  # Place so centroid lands at ring center, then apply manual offsets
  $destX = [int]([math]::Round($centerX - $cxScaled + $OffsetX))
  $destY = [int]([math]::Round($centerY - $cyScaled + $OffsetY))
  $destRect = New-Object System.Drawing.Rectangle $destX, $destY, $destW, $destH
  $gfx.DrawImage($img, $destRect)
  $img.Dispose()
}

# Clean up
$pen.Dispose(); $gfx.Dispose()
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

Write-Host "Generated: $outPath"
