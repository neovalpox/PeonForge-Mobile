# PeonForge Mobile — Release script
# Increments version, builds APK, uploads to site, updates version.json
# Usage: powershell -ExecutionPolicy Bypass -File release.ps1 [-Major] [-Minor] [-Patch] [-Message "changelog"]

param(
    [switch]$Major,
    [switch]$Minor,
    [string]$Message = "Mise a jour disponible"
)

$ErrorActionPreference = "Stop"

# Read current version from pubspec.yaml
$pubspec = Get-Content "pubspec.yaml" -Raw
$match = [regex]::Match($pubspec, 'version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)')
if (-not $match.Success) { Write-Host "Cannot parse version from pubspec.yaml" -ForegroundColor Red; exit 1 }

$maj = [int]$match.Groups[1].Value
$min = [int]$match.Groups[2].Value
$pat = [int]$match.Groups[3].Value
$build = [int]$match.Groups[4].Value

$oldVer = "$maj.$min.$pat"

# Increment
if ($Major) {
    $maj++; $min = 0; $pat = 0
} elseif ($Minor) {
    $min++; $pat = 0
} else {
    $pat++
}
$build++
$newVer = "$maj.$min.$pat"

Write-Host ""
Write-Host "  PeonForge Mobile Release" -ForegroundColor Cyan
Write-Host "  $oldVer -> $newVer (build $build)" -ForegroundColor Yellow
Write-Host ""

# Update pubspec.yaml
$pubspec = $pubspec -replace "version:\s*[\d.]+\+\d+", "version: $newVer+$build"
Set-Content "pubspec.yaml" -Value $pubspec -Encoding UTF8 -NoNewline
Write-Host "  [1/5] pubspec.yaml updated" -ForegroundColor Green

# Update _currentVersion in main.dart
$mainDart = Get-Content "lib/main.dart" -Raw
$mainDart = $mainDart -replace "static const _currentVersion = '[^']+';", "static const _currentVersion = '$newVer';"
Set-Content "lib/main.dart" -Value $mainDart -Encoding UTF8 -NoNewline
Write-Host "  [2/5] main.dart version updated" -ForegroundColor Green

# Build APK
Write-Host "  [3/5] Building APK..." -ForegroundColor Yellow
$env:JAVA_HOME = "C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot"
& "$env:USERPROFILE\flutter\bin\flutter" build apk --release 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host "  Build failed!" -ForegroundColor Red; exit 1 }
Write-Host "  [3/5] APK built" -ForegroundColor Green

# Upload APK
Write-Host "  [4/5] Uploading to peonforge.ch..." -ForegroundColor Yellow
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
scp $apkPath gw8042_claude@gw8042.ftp.infomaniak.com:~/sites/peonforge.ch/PeonForge.apk 2>&1 | Out-Null
Write-Host "  [4/5] APK uploaded" -ForegroundColor Green

# Update version.json on server
Write-Host "  [5/5] Updating version.json..." -ForegroundColor Yellow
$versionJson = "{`"version`":`"$newVer`",`"apk_url`":`"https://peonforge.ch/PeonForge.apk`",`"changelog`":`"$Message`"}"
$versionJson | ssh gw8042_claude@gw8042.ftp.infomaniak.com "cat > ~/sites/peonforge.ch/version.json" 2>&1 | Out-Null
Write-Host "  [5/5] version.json updated" -ForegroundColor Green

# Git commit
& git add pubspec.yaml lib/main.dart
& git commit -m "Release v$newVer - $Message`n`nCo-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
& git push origin main

Write-Host ""
Write-Host "  Release v$newVer complete!" -ForegroundColor Green
Write-Host "  All mobile clients will see the update dialog." -ForegroundColor DarkGray
Write-Host ""
