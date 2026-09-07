<#
  _config.ps1 -- shared paths for the Timoté build scripts (single source of truth).
  Dot-source at the top of every *.ps1:   . "$PSScriptRoot\_config.ps1"
  then use $Cfg.build / $Cfg.tree / $Cfg.ffmpeg / $Cfg.ffprobe / $Cfg.uv / $Cfg.src
#>
$Cfg = [pscustomobject]@{
    src      = 'C:\Users\gia_a\Music\Timoté'
    build    = 'C:\Users\gia_a\Music\Timoté\_build'
    tree     = 'C:\Users\gia_a\Music\Timoté\_build\tree'
    rawAudio = 'C:\Users\gia_a\Music\Timoté\_build\work\raw_audio'
    ffmpeg   = 'C:\Program Files\ffmpeg\bin\ffmpeg.exe'
    ffprobe  = 'C:\Program Files\ffmpeg\bin\ffprobe.exe'
    uv       = 'C:\Users\gia_a\AppData\Local\Microsoft\WinGet\Packages\astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe\uv.exe'
}

# key of a tree audio file in work\raw_audio: "<parent dir>__<file name>".
# Mirror of bak_name() in _config.py -- keep the two in sync.
function BakName([string]$fullPath) {
    (Split-Path (Split-Path $fullPath -Parent) -Leaf) + '__' + (Split-Path $fullPath -Leaf)
}
