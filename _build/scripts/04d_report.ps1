<# Re-measure loudness of every normalised asset -> audio_report.csv #>
$ErrorActionPreference = 'Stop'
[Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
. "$PSScriptRoot\_config.ps1"
$build = $Cfg.build; $tree = $Cfg.tree
$ffmpeg = Assert-Tool $Cfg.ffmpeg 'ffmpeg'; $ffprobe = Assert-Tool $Cfg.ffprobe 'ffprobe'
$sr = $Cfg.audio.sample_rate; $ch = $Cfg.audio.channels
$cl = if ($ch -eq 1) { 'mono' } else { 'stereo' }
$fmtWant = "$sr,$ch"
$tLufs = $Cfg.audio.target_lufs

$rows = foreach ($f in (Get-ChildItem -LiteralPath $tree -Recurse -Filter *.mp3 | Sort-Object FullName)) {
    $m = Measure-Loudness $f.FullName $cl
    $j = & $ffprobe -v error -show_entries stream=sample_rate,channels `
         -of csv=p=0 -- $f.FullName
    [pscustomobject]@{
        file = $f.FullName.Substring($tree.Length + 1)
        lufs = $m.lufs; peak_dbfs = $m.peak; fmt = $j
    }
}
$rows | Export-Csv -LiteralPath (Join-Path $build 'audio_report.csv') -NoTypeInformation -Encoding UTF8
$l = [double[]]($rows.lufs | Where-Object { $_ -ne $null })
$p = [double[]]($rows.peak_dbfs | Where-Object { $_ -ne $null })
"{0} fichiers" -f $rows.Count
"LUFS : min={0:N1} max={1:N1} moy={2:N1}" -f ($l|measure -min).Minimum,($l|measure -max).Maximum,($l|measure -average).Average
"PEAK : min={0:N1} max={1:N1}" -f ($p|measure -min).Minimum,($p|measure -max).Maximum
"hors $fmtWant : {0}" -f ($rows | Where-Object { $_.fmt -ne $fmtWant }).Count
$rows | Where-Object { $_.fmt -ne $fmtWant -or [math]::Abs([double]$_.lufs - $tLufs) -gt 1.5 } |
    ForEach-Object { "  ! {0}  {1} LUFS  {2}" -f $_.file, $_.lufs, $_.fmt }
