param(
    [string]$Version = "v0.4.0"
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$OutDir = Join-Path $RootDir "_release-temp"
$ZipName = "SlimPaste-$Version.zip"
$ZipPath = Join-Path $RootDir $ZipName

# Clean previous
if (Test-Path $OutDir) { Remove-Item $OutDir -Recurse -Force }
$null = New-Item -ItemType Directory -Path $OutDir -Force

$files = @(
    "SlimPaste.exe",
    "setup\Settings.exe",
    "setup\settings-wpf.ps1",
    "setup\setup.axml",
    "worker\clipboard-jpeg-worker.ps1",
    "bin\jpegli\cjpegli.exe",
    "config\default-config.ini",
    "themes.ini",
    "assets\icon.ico",
    "LICENSE",
    "THIRD_PARTY_NOTICES.md",
    "README.md",
    "README.en.md"
)

foreach ($f in $files) {
    $src = Join-Path $RootDir $f
    $dst = Join-Path $OutDir $f
    $parent = Split-Path $dst -Parent
    if (-not (Test-Path $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
    Copy-Item $src $dst
}

# Create zip
if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($OutDir, $ZipPath)

Remove-Item $OutDir -Recurse -Force

Write-Host "Release package created: $ZipPath"
