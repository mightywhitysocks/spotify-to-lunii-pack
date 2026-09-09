<#
  01_inventory.ps1
  Parse the source media files, probe duration + loudness (EBU R128),
  group chapters into stories, drop discards, assign categories.
  Everything project-specific comes from project.json ($Cfg).
  Outputs: inventory.csv, stories.json, categories.csv
#>
$ErrorActionPreference = 'Stop'
[Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'   # period decimals in CSV/JSON
. "$PSScriptRoot\_config.ps1"
$src = $Cfg.src; $build = $Cfg.build
$ffprobe = Assert-Tool $Cfg.ffprobe 'ffprobe'
$null = Assert-Tool $Cfg.ffmpeg 'ffmpeg'   # guard only; Measure-Loudness calls $Cfg.ffmpeg

function Remove-Accents([string]$s) {
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    -join ($n.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'
    })
}
function Story-Key([string]$title) {
    $t = (Remove-Accents $title).ToLower()
    if ($Cfg.story_key_strip_prefix) { $t = $t -replace $Cfg.story_key_strip_prefix, "" }
    ($t -replace "[^a-z0-9]+", " ").Trim()
}

# ---- category assignment by story key (from $Cfg.categories) --------------
$cats = @($Cfg.categories)
$flat = ($cats.Count -eq 0)               # no categories -> flat single-level menu
$catName = @{}                            # story key -> category name
$catRank = @{}                            # category name -> position (for stable ordering)
for ($i = 0; $i -lt $cats.Count; $i++) {
    $catRank[$cats[$i].name] = $i
    foreach ($sk in @($cats[$i].stories)) { $catName[$sk] = $cats[$i].name }
}
$catRank[$Cfg.uncategorized_name] = 9999

$discard = $Cfg.discard
$pat = $Cfg.filenamePatternNet
$gNum = $Cfg.num_group; $gChap = $Cfg.chapter_group; $gTitle = $Cfg.title_group

# ---- scan files -------------------------------------------------------
$files = Get-ChildItem -LiteralPath $src -File | Where-Object { Test-SourceFile $_.Name } | Sort-Object Name
$rows = foreach ($f in $files) {
    $stem = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    if ($stem -notmatch $pat) { Write-Warning "non reconnu: $($f.Name)"; continue }
    $num   = $Matches[$gNum]
    $chap  = if ($Matches.ContainsKey($gChap)) { $Matches[$gChap] } else { $null }
    $title = $Matches[$gTitle].Trim()

    $dur = & $ffprobe -v error -show_entries format=duration -of csv=p=0 -- $f.FullName
    $lu  = Measure-Loudness $f.FullName 'mono'

    [pscustomobject]@{
        num      = $num
        chapter  = if ($chap) { [int]$chap } else { 0 }
        title    = $title
        key      = Story-Key $title
        file     = $f.Name
        seconds  = [math]::Round([double]$dur, 1)
        lufs     = $lu.lufs
        peak_dbfs= $lu.peak
        status   = if ($discard.ContainsKey($num)) { "ecarte: $($discard[$num])" } else { 'garde' }
    }
}

$rows | Export-Csv -LiteralPath (Join-Path $build 'inventory.csv') -NoTypeInformation -Encoding UTF8
Write-Host ("inventory.csv : {0} fichiers ({1} gardes)" -f $rows.Count, ($rows | Where-Object status -eq 'garde').Count)

# ---- build stories --------------------------------------------------
$kept = $rows | Where-Object status -eq 'garde'
$stories = foreach ($grp in ($kept | Group-Object key | Sort-Object Name)) {
    $parts = $grp.Group | Sort-Object chapter, num
    $key   = $grp.Name
    if ($flat) {
        $cat = ''
    } else {
        $cat = $catName[$key]
        if (-not $cat) { Write-Warning "sans categorie: '$key' -> $($Cfg.uncategorized_name)"; $cat = $Cfg.uncategorized_name }
    }
    [pscustomobject]@{
        key       = $key
        slug      = $Cfg.slug_prefix + ($key -replace ' ', '-')   # STABLE id (independent of category)
        title     = $parts[0].title                               # display title with accents
        category  = $cat
        chapters  = @($parts | ForEach-Object { $_.file })
        seconds   = [math]::Round((($parts | Measure-Object seconds -Sum).Sum), 1)
        lufs      = @($parts | ForEach-Object { $_.lufs })
        peak_dbfs = @($parts | ForEach-Object { $_.peak_dbfs })
    }
}

$stories = $stories | Sort-Object @{e={ if ($catRank.ContainsKey($_.category)) { $catRank[$_.category] } else { 9998 } }}, title
$stories | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $build 'stories.json') -Encoding UTF8
$stories | Select-Object category, title, @{n='nb_chap';e={$_.chapters.Count}}, seconds |
    Export-Csv -LiteralPath (Join-Path $build 'categories.csv') -NoTypeInformation -Encoding UTF8

Write-Host ("stories.json  : {0} histoires" -f $stories.Count)
if (-not $flat) {
    "`n--- repartition par categorie ---"
    $stories | Group-Object category | Sort-Object Name | Format-Table Name, Count -AutoSize
}
"`n--- histoires a 1 seule piste ---"
$stories | Where-Object { $_.chapters.Count -eq 1 } | ForEach-Object { " - $($_.title)" }
