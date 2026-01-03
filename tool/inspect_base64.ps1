param(
  [Parameter(Mandatory=$true)][string]$Path,
  [int]$ProbePos = 12210,
  [int]$Context = 80
)

if (!(Test-Path -LiteralPath $Path)) {
  Write-Error "File not found: $Path"; exit 1
}

$c = Get-Content -Raw -LiteralPath $Path
$len = $c.Length
Write-Output ("length=$len chars")

# Show a window of characters around the probe position
$start = [Math]::Max(0, [Math]::Min($ProbePos, $len) - [int]($Context/2))
$take = [Math]::Min($Context, $len - $start)
$seg = $c.Substring($start, $take)
Write-Output ("window[@$start..$([int]($start+$take-1))]:")
Write-Output $seg

# Count invalid characters
$allowed = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/='
$invalid = @()
for ($i=0; $i -lt $len; $i++) {
  $ch = $c[$i]
  if (($ch -eq "`r") -or ($ch -eq "`n")) { continue }
  if ($allowed.Contains([char]$ch)) { continue }
  # URL-safe support
  if (([char]$ch) -eq '-') { continue }
  if (([char]$ch) -eq '_') { continue }
  $invalid += @{ idx=$i; ch=([char]$ch); code=[int]$ch }
  if ($invalid.Count -ge 20) { break }
}
if ($invalid.Count -gt 0) {
  Write-Output ("invalidCharsFirst${($invalid.Count))}:")
  foreach ($it in $invalid) {
    Write-Output (" idx={0} ch='{1}' code={2}" -f $it.idx, $it.ch, $it.code)
  }
} else {
  Write-Output "invalidChars=0"
}

# Look for common AAR/ZIP base64 footer 'UEsFB'
$footerIdx = $c.IndexOf('UEsFB')
Write-Output ("UEsFB_index=$footerIdx")
