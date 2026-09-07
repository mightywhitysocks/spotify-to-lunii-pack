<#
  04b_normalize.ps1
  Loudness-normalise every audio asset in the tree with ffmpeg-normalize
  (EBU R128, two-pass): target -16 LUFS integrated, -1.5 dBTP, 44.1kHz mono MP3.
  Sources are hot (~-12.4 LUFS) and clipped (~+2.3 dBTP) -> this pulls them
  down to a consistent, un-clipped level.

  IDEMPOTENT: a pristine copy of every file is kept under work\raw_audio and
  normalisation ALWAYS runs from that copy, so re-running never double-compresses.
  Each generator invalidates its own backups (02_merge moves / -Rebuild purges;
  03_titles + 04_menu_tts delete what they re-wrote), so a plain re-run is safe.
  -Only '<pat>'  restricts to files whose relative path matches; -Fresh is a
  paranoia reset that rebuilds every backup from the current tree.
  Outputs: audio_report.csv
#>
param([switch]$Fresh, [string[]]$Only)
$ErrorActionPreference = 'Stop'
[Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
. "$PSScriptRoot\_config.ps1"
$build  = $Cfg.build
$tree   = $Cfg.tree
$uv     = $Cfg.uv
$ffmpeg = $Cfg.ffmpeg
$env:FFMPEG_PATH = $ffmpeg
$raw = $Cfg.rawAudio
if ($Fresh -and (Test-Path -LiteralPath $raw)) {
    Write-Host "-Fresh : suppression des copies pristine ($raw)"
    Remove-Item -LiteralPath $raw -Recurse -Force
}
New-Item -ItemType Directory -Force $raw | Out-Null

function Measure-LU([string]$p) {
    $o = (& $ffmpeg -hide_banner -nostats -i $p -map 0:a:0 `
          -af 'aformat=channel_layouts=mono,ebur128=peak=true' -f null - 2>&1) -join "`n"
    $I  = if ($o -match '(?s)Integrated loudness:.*?I:\s*(-?[\d.]+)\s*LUFS') { [double]$Matches[1] } else { $null }
    $TP = if ($o -match '(?s)True peak:.*?Peak:\s*(-?[\d.]+)\s*dBFS') { [double]$Matches[1] } else { $null }
    [pscustomobject]@{ I = $I; TP = $TP }
}

$files = Get-ChildItem -LiteralPath $tree -Recurse -Filter *.mp3 | Sort-Object FullName
if ($Only) {
    $re = ($Only | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $files = $files | Where-Object { $_.FullName.Substring($tree.Length + 1) -match $re }
}
Write-Host ("normalisation de {0} fichiers -> -16 LUFS / -1.5 dBTP ..." -f $files.Count)
$report = foreach ($f in $files) {
    $bak = Join-Path $raw (BakName $f.FullName)
    if (-not (Test-Path -LiteralPath $bak)) {
        # first time we see this file: the tree copy is the pristine source
        Copy-Item -LiteralPath $f.FullName -Destination $bak -Force
    }
    # measure the PRISTINE copy (the tree file may already be normalised)
    $before = Measure-LU $bak
    $tmp = "$($f.FullName).norm.mp3"
    & $uv tool run --from ffmpeg-normalize ffmpeg-normalize $bak -o $tmp -f `
        -t -16 -tp -1.5 -nt ebu -c:a libmp3lame -b:a 256k -ar 44100 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tmp)) { throw "normalize failed: $($f.Name)" }
    Move-Item -LiteralPath $tmp -Destination $f.FullName -Force
    $after = Measure-LU $f.FullName
    Write-Host ("  {0,-42} {1,6} -> {2,6} LUFS  (tp {3})" -f $f.Name, $before.I, $after.I, $after.TP)
    [pscustomobject]@{
        file = $f.FullName.Substring($tree.Length + 1)
        lufs_before = $before.I; peak_before = $before.TP
        lufs_after  = $after.I;  peak_after  = $after.TP
    }
}
$report | Export-Csv -LiteralPath (Join-Path $build 'audio_report.csv') -NoTypeInformation -Encoding UTF8
$la = [double[]]($report.lufs_after | Where-Object { $_ -ne $null })
Write-Host ("`nOK - LUFS apres : min={0:N1} max={1:N1} moy={2:N1}  (cible -16)" -f `
    ($la|measure -min).Minimum, ($la|measure -max).Maximum, ($la|measure -average).Average)
