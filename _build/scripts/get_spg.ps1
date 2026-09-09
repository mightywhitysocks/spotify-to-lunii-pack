<#
  get_spg.ps1 -- fetch the pinned studio-pack-generator build into _build\tools\spg\.

  SPG is a ~30-90 MB self-contained binary (ffmpeg + ImageMagick embedded), not
  vendored in git. This downloads the exact release this project targets from
  jersou/studio-pack-generator, checks its SHA-256 (digests published by GitHub
  on the v0.5.15 assets), and unzips it where _config.ps1 / _config.py auto-detect
  it -- so after this, tools.spg can stay blank in project.local.json.

  Usage:  pwsh scripts\get_spg.ps1 [-Force]
    -Force   re-download even if _build\tools\spg\ already holds a binary.

  Piper voice + whisper model are fetched on demand by `uv` at run time; only
  SPG needs a script. If that changes, add get_piper.ps1 the same way.
#>
param([switch]$Force)
$ErrorActionPreference = 'Stop'

$Version   = '0.5.15'
$BuildDir  = Split-Path $PSScriptRoot -Parent
$SpgDir    = Join-Path $BuildDir 'tools\spg'
$ZipPath   = Join-Path $BuildDir 'tools\spg.zip'

# platform key -> release asset + its SHA-256 (from the GitHub asset digest).
$Assets = @{
    'x86_64-windows' = @{ File = "studio-pack-generator-$Version-x86_64-windows.zip"; Sha256 = '054ca22fe02f5121fb9ed978d68341980469ecbf0329d0eb21d9f9c42c7c548c' }
    'x86_64-linux'   = @{ File = "studio-pack-generator-$Version-x86_64-linux.zip";   Sha256 = 'dfca83070199cac5220afe61c75ee2d4215d96f636aa9f8b4ff74d82353786a7' }
    'x86_64-apple'   = @{ File = "studio-pack-generator-$Version-x86_64-apple.zip";   Sha256 = '9ff76cf0c6cf1912cf3c5ee59910367a70fcfe7b6137b15e95b6a2f4c1a9a132' }
    'aarch64-apple'  = @{ File = "studio-pack-generator-$Version-aarch64-apple.zip";  Sha256 = '4318ef4501101cb4cdb941d4ea7a77dc7b0e1392c3c8c11bd7ba9f0d158b70ea' }
}

function Get-PlatformKey {
    $arch = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString().ToLower()  # x64 | arm64 | ...
    if ($IsWindows -or $env:OS -eq 'Windows_NT') { return 'x86_64-windows' }
    if ($IsMacOS)   { return ($arch -match 'arm|aarch' ? 'aarch64-apple' : 'x86_64-apple') }
    if ($IsLinux)   { return 'x86_64-linux' }
    throw "plateforme non reconnue (arch=$arch) -- télécharge SPG $Version à la main dans $SpgDir"
}

function Find-SpgBinary {
    # the lone executable the release zip unpacks under $SpgDir
    Get-ChildItem -LiteralPath $SpgDir -Recurse -File -Filter 'studio-pack-generator*' -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '\.(zip|txt|md)$' } | Select-Object -First 1
}

$key = Get-PlatformKey
$asset = $Assets[$key]
$existing = Find-SpgBinary
if ($existing -and -not $Force) {
    Write-Host "SPG déjà présent : $($existing.FullName)`n(-Force pour re-télécharger)"
    return
}

$url = "https://github.com/jersou/studio-pack-generator/releases/download/v$Version/$($asset.File)"
New-Item -ItemType Directory -Force (Split-Path $ZipPath -Parent) | Out-Null
Write-Host "téléchargement $($asset.File) ..."
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $ZipPath

$got = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLower()
if ($got -ne $asset.Sha256) {
    Remove-Item -LiteralPath $ZipPath -Force
    throw "checksum SHA-256 invalide pour $($asset.File)`n  attendu : $($asset.Sha256)`n  obtenu  : $got"
}
Write-Host "checksum OK"

Remove-Item -LiteralPath $SpgDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $SpgDir | Out-Null
Expand-Archive -LiteralPath $ZipPath -DestinationPath $SpgDir -Force

$bin = Find-SpgBinary
if (-not $bin) { throw "binaire introuvable après extraction dans $SpgDir" }
if ($IsLinux -or $IsMacOS) { chmod +x $bin.FullName }
Write-Host "`nOK — SPG $Version : $($bin.FullName)"
Write-Host "tools.spg peut rester vide dans project.local.json (auto-détecté)."
