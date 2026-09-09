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
  paranoia reset that rebuilds every backup from the current tree. Iterating on a
  few clips? -Only keeps a run to seconds -- a full ~100-file run is ~10 min
  (ffmpeg-normalize's own two passes dominate; see issue #27).
  Outputs: normalize_report.csv (before/after delta, processed files only).
  "before" figures come from ffmpeg-normalize's --print-stats (its pass 1 already
  measures the pristine input) -- no extra ffmpeg pass. "after" is a real
  re-measure of the encoded file. The canonical full loudness/format snapshot is
  audio_report.csv, written by 04d_report.ps1.
#>
param([switch]$Fresh, [string[]]$Only)
$ErrorActionPreference = 'Stop'
[Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
. "$PSScriptRoot\_config.ps1"
$build  = $Cfg.build
$tree   = $Cfg.tree
$uv     = Assert-Tool $Cfg.uv 'uv'
$ffmpeg = Assert-Tool $Cfg.ffmpeg 'ffmpeg'
$env:FFMPEG_PATH = $ffmpeg
$raw = $Cfg.rawAudio
$sr  = $Cfg.audio.sample_rate; $ch = $Cfg.audio.channels
$cl  = if ($ch -eq 1) { 'mono' } else { 'stereo' }
$tLufs = $Cfg.audio.target_lufs; $tTp = $Cfg.audio.target_tp
$codec = $Cfg.audio.codec; $brate = $Cfg.audio.bitrate
if ($Fresh -and (Test-Path -LiteralPath $raw)) {
    Write-Host "-Fresh : suppression des copies pristine ($raw)"
    Remove-Item -LiteralPath $raw -Recurse -Force
}
New-Item -ItemType Directory -Force $raw | Out-Null

$files = Get-ChildItem -LiteralPath $tree -Recurse -Filter *.mp3 | Sort-Object FullName
if ($Only) {
    $re = ($Only | ForEach-Object { [regex]::Escape($_) }) -join '|'
    $files = $files | Where-Object { $_.FullName.Substring($tree.Length + 1) -match $re }
}
Write-Host ("normalisation de {0} fichiers -> {1} LUFS / {2} dBTP ..." -f $files.Count, $tLufs, $tTp)
$report = foreach ($f in $files) {
    $bak = Join-Path $raw (BakName $f.FullName)
    if (-not (Test-Path -LiteralPath $bak)) {
        # first time we see this file: the tree copy is the pristine source
        Copy-Item -LiteralPath $f.FullName -Destination $bak -Force
    }
    $tmp = "$($f.FullName).norm.mp3"
    # --print-stats emits JSON on stdout; ffmpeg-normalize's pass 1 measures the
    # pristine $bak, so ebu_pass1 is the "before" delta with no extra ffmpeg pass.
    $stats = & $uv tool run --from ffmpeg-normalize ffmpeg-normalize $bak -o $tmp -f `
        -t $tLufs -tp $tTp -nt ebu -c:a $codec -b:a $brate -ar $sr --print-stats 2>$null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tmp)) { throw "normalize failed: $($f.Name)" }
    Move-Item -LiteralPath $tmp -Destination $f.FullName -Force
    $p1 = (@($stats | ConvertFrom-Json)[0]).ebu_pass1
    $after = Measure-Loudness $f.FullName $cl
    Write-Host ("  {0,-42} {1,6} -> {2,6} LUFS  (tp {3})" -f $f.Name, $p1.input_i, $after.lufs, $after.peak)
    [pscustomobject]@{
        file = $f.FullName.Substring($tree.Length + 1)
        lufs_before = $p1.input_i; peak_before = $p1.input_tp
        lufs_after  = $after.lufs;  peak_after  = $after.peak
    }
}
$report | Export-Csv -LiteralPath (Join-Path $build 'normalize_report.csv') -NoTypeInformation -Encoding UTF8
$la = [double[]]($report.lufs_after | Where-Object { $_ -ne $null })
Write-Host ("`nOK - LUFS apres : min={0:N1} max={1:N1} moy={2:N1}  (cible {3})" -f `
    ($la|measure -min).Minimum, ($la|measure -max).Maximum, ($la|measure -average).Average, $tLufs)
