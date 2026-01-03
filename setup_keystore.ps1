param(
    [string]$KeystorePath = "android/app/upload-keystore.jks",
    [string]$Alias = "kincircle",
    [string]$StorePassword = "kincircle",
    [string]$KeyPassword = "kincircle"
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$resolvedKeystorePath = Join-Path $root $KeystorePath

function Resolve-KeytoolPath {
    $command = Get-Command keytool -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    if ($env:JAVA_HOME) {
        $javaHomeCandidate = Join-Path $env:JAVA_HOME 'bin/keytool.exe'
        if (Test-Path $javaHomeCandidate) {
            return $javaHomeCandidate
        }
    }

    $androidStudioCandidate = 'C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe'
    if (Test-Path $androidStudioCandidate) {
        return $androidStudioCandidate
    }

    return $null
}

$keytoolPath = Resolve-KeytoolPath
if (-not $keytoolPath) {
    Write-Error "Unable to locate 'keytool'. Install a JDK or ensure keytool is on PATH."
    exit 1
}

$keystoreDirectory = Split-Path -Parent $resolvedKeystorePath
if (-not (Test-Path $keystoreDirectory)) {
    New-Item -Path $keystoreDirectory -ItemType Directory | Out-Null
}

if (Test-Path $resolvedKeystorePath) {
    Write-Host "Keystore already exists at $resolvedKeystorePath. Delete it manually if you want to recreate it."
    exit 0
}

$keytoolArgs = @(
    "-genkeypair",
    "-v",
    "-keystore", $resolvedKeystorePath,
    "-storepass", $StorePassword,
    "-alias", $Alias,
    "-keypass", $KeyPassword,
    "-keyalg", "RSA",
    "-keysize", "2048",
    "-validity", "3650",
    "-dname", "CN=KinCircle, OU=Engineering, O=KinCircle, L=Austin, S=Texas, C=US"
)

Write-Host "Generating keystore at $resolvedKeystorePath..."
& $keytoolPath @keytoolArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to generate keystore (exit code $LASTEXITCODE)."
    exit $LASTEXITCODE
}

Write-Host "Keystore generated successfully."
