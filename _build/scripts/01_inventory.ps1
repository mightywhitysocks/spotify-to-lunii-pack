<#
  01_inventory.ps1
  Parse the 99 source MP3s, probe duration + loudness (EBU R128),
  group into stories, deduplicate, assign categories.
  Outputs: inventory.csv, stories.json, categories.csv
#>
$ErrorActionPreference = 'Stop'
[Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'   # period decimals in CSV/JSON
. "$PSScriptRoot\_config.ps1"
$src = $Cfg.src; $build = $Cfg.build; $ffprobe = $Cfg.ffprobe; $ffmpeg = $Cfg.ffmpeg

function Remove-Accents([string]$s) {
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    -join ($n.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark'
    })
}
function Story-Key([string]$title) {
    $t = Remove-Accents $title
    $t = $t.ToLower() -replace "^timote\s+", "" -replace "[^a-z0-9]+", " "
    $t.Trim()
}

# ---- category assignment by story key ------------------------------------
$catOrder = @(
  '1 Quotidien et autonomie','2 Emotions et grandir','3 Ecole',
  '4 Sorties et culture','5 Voyages','6 Sport et plein air',
  '7 Fetes','8 Corps et sante','9 Nature et animaux'
)
$catMap = @{
  'fait un gateau'          = 1; 'jardine'                 = 1
  'aime tout faire tout seul'=1; 'et son doudou'           = 1
  'et sa tetine'            = 1
  'et ses emotions'         = 2; 'est amoureux'            = 2
  'devient grand frere'     = 2; 'et la petite souris'     = 2
  'dort chez un copain'     = 2; 'et les ecrans'           = 2
  'fait des betises'        = 2
  'entre a l ecole'         = 3; 'va a la cantine'         = 3
  'apprend l anglais'       = 3; 'va au centre de loisirs' = 3
  'aime la musique'         = 3
  'decouvre les chiffres'   = 3; 'decouvre les lettres'    = 3   # -> Ecole (etait Quotidien)
  'visite le musee d orsay' = 4; 'visite le louvre'        = 4
  'va au spectacle'         = 4
  'va a la bibliotheque'    = 4; 'a l aquarium'            = 4
  'va au cirque'            = 4; 'visite un chateau fort'  = 4
  'visite la bretagne'      = 5; 'prend le train'          = 5
  'visite paris'            = 5                                  # -> Voyages (etait Sorties)
  'joue au foot'            = 6; 'fait du velo'            = 6
  'fait du ski'             = 6; 'fait de la trottinette'  = 6
  'fete son anniversaire'   = 7; 'fete la saint nicolas'   = 7
  'et le noel magique'      = 7
  'est malade'              = 8; 'va chez le docteur'      = 8
  'et ses lunettes'         = 8
  'aime la planete'         = 9; 'veut un animal'          = 9
  'a la ferme'              = 9; 'et le chantier'          = 9
  'chez les pompiers'       = 9
  'se promene en foret'     = 9                                  # -> Nature (etait Sport)
}

$discard = @{
  '091'='doublon de 008'; '097'='doublon de 065'; '109'='doublon de 031'
  '133'='doublon de 003'; '141'='doublon de 014'; '197'='doublon de 062'
  '242'='doublon de 013'; '248'='doublon de 033'
  '082'='chapitre 1 seul (au bord de la mer)'
  '147'='chapitre 1 seul (fait du poney)'
  '115'='fragment Volume 3'; '121'='fragment Volume 3'
  '127'='fragment Volume 3'; '139'='fragment Volume 3'
}

# ---- scan files --------------------------------------------------------
$files = Get-ChildItem -LiteralPath $src -Filter *.mp3 | Sort-Object Name
$rows = foreach ($f in $files) {
    if ($f.Name -notmatch '^(\d+) Timoté - (?:Chapitre (\d+) - )?(.+?)(?: - Timoté)?\.mp3$') {
        Write-Warning "unparsed: $($f.Name)"; continue
    }
    $num = $Matches[1]; $chap = $Matches[2]; $title = $Matches[3].Trim()

    $dur = & $ffprobe -v error -show_entries format=duration -of csv=p=0 -- $f.FullName
    $eb  = & $ffmpeg -hide_banner -nostats -i $f.FullName -map 0:a:0 `
             -af 'aformat=channel_layouts=mono,ebur128=peak=true' -f null - 2>&1
    $ebt = $eb -join "`n"
    $I    = if ($ebt -match '(?s)Integrated loudness:.*?I:\s*(-?\d+(?:\.\d+)?)\s*LUFS') { [double]$Matches[1] } else { $null }
    $peak = if ($ebt -match '(?s)True peak:.*?Peak:\s*(-?\d+(?:\.\d+)?)\s*dBFS') { [double]$Matches[1] } else { $null }

    [pscustomobject]@{
        num      = $num
        chapter  = if ($chap) { [int]$chap } else { 0 }
        title    = $title
        key      = Story-Key $title
        file     = $f.Name
        seconds  = [math]::Round([double]$dur, 1)
        lufs     = $I
        peak_dbfs= $peak
        status   = if ($discard.ContainsKey($num)) { "ecarte: $($discard[$num])" } else { 'garde' }
    }
}

$rows | Export-Csv -LiteralPath (Join-Path $build 'inventory.csv') -NoTypeInformation -Encoding UTF8
Write-Host ("inventory.csv : {0} fichiers ({1} gardes)" -f $rows.Count, ($rows | Where-Object status -eq 'garde').Count)

# ---- build stories ----------------------------------------------------
$kept = $rows | Where-Object status -eq 'garde'
$stories = foreach ($grp in ($kept | Group-Object key | Sort-Object Name)) {
    $parts = $grp.Group | Sort-Object chapter, num
    $key   = $grp.Name
    $catId = $catMap[$key]
    if (-not $catId) { Write-Warning "PAS DE CATEGORIE pour '$key'"; $catId = 9 }
    $niceTitle = ($parts[0].title)   # display title with accents
    [pscustomobject]@{
        key       = $key
        slug      = 'timote-' + ($key -replace ' ', '-')   # STABLE id (independent of category)
        title     = $niceTitle
        category  = $catOrder[$catId - 1]
        chapters  = @($parts | ForEach-Object { $_.file })
        seconds   = [math]::Round((($parts | Measure-Object seconds -Sum).Sum), 1)
        lufs      = @($parts | ForEach-Object { $_.lufs })
        peak_dbfs = @($parts | ForEach-Object { $_.peak_dbfs })
    }
}

$stories = $stories | Sort-Object category, title
$stories | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $build 'stories.json') -Encoding UTF8
$stories | Select-Object category, title, @{n='nb_chap';e={$_.chapters.Count}}, seconds |
    Export-Csv -LiteralPath (Join-Path $build 'categories.csv') -NoTypeInformation -Encoding UTF8

Write-Host ("stories.json  : {0} histoires" -f $stories.Count)
"`n--- repartition par categorie ---"
$stories | Group-Object category | Sort-Object Name | Format-Table Name, Count -AutoSize
"`n--- histoires a 1 seule piste ---"
$stories | Where-Object { $_.chapters.Count -eq 1 } | ForEach-Object { " - $($_.title)" }
