<#
  02_merge.ps1
  Build the SPG folder tree: one story audio file per story (chapters merged,
  edge-silence trimmed, a gap between chapters, small guard silence).
  Container / codec / sample-rate / channels / gaps all come from $Cfg.audio +
  $Cfg.merge. No loudness change here (done in 04b_normalize).

  RECONCILE (not wipe): the story audio only depends on the source chapters,
  never on the category. So a re-run re-uses every merged clip that already
  exists and just MOVES it to its (possibly new) category / index slot -- and
  moves its .item.mp3 / .item.png / loudness backup with it. Only genuinely new
  stories are re-encoded. -Rebuild forces a full re-merge.

  When $Cfg.categories is empty the menu is flat: every story goes straight
  under the menu root, no category sub-folders.

  The JSON `base` is the STABLE slug, independent of category, so
  title_windows.csv / cover_tune.csv keys survive a recategorisation.
  Outputs: _build\tree\... , _build\stories_tree.json
#>
param([switch]$Rebuild)
$ErrorActionPreference = 'Stop'
[Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
. "$PSScriptRoot\_config.ps1"
$src = $Cfg.src; $build = $Cfg.build; $tree = $Cfg.tree
$ffmpeg = Assert-Tool $Cfg.ffmpeg 'ffmpeg'
$menu   = $Cfg.menu
$rawDir = $Cfg.rawAudio
$flat   = (@($Cfg.categories).Count -eq 0)

$sr = $Cfg.audio.sample_rate; $ch = $Cfg.audio.channels
$cl = if ($ch -eq 1) { 'mono' } else { 'stereo' }
$storyExt = 'mp3'      # story audio is always re-encoded to mp3 for the Lunii
$lead = $Cfg.merge.lead; $tail = $Cfg.merge.tail; $gap = $Cfg.merge.gap
$headDb = $Cfg.merge.trim_head_db; $headWin = $Cfg.merge.trim_head_window
$tailDb = $Cfg.merge.trim_tail_db; $tailWin = $Cfg.merge.trim_tail_window
$det    = $Cfg.merge.trim_detection; $pad = $Cfg.merge.trim_pad

function Slug([string]$s) {
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    $a = -join ($n.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    ($a -replace "[^A-Za-z0-9]+", " ").Trim()
}
function MoveIfNeeded($from, $to) {
    if ((Test-Path -LiteralPath $from) -and $from -ne $to) {
        Move-Item -LiteralPath $from -Destination $to -Force
    }
}
function ToTreeRelative($p) { [IO.Path]::GetRelativePath($tree, $p) }

# Edge-trim filter fragments -- applied ONLY to the story's two real external
# edges (very start of chapter 1, very end of the last chapter). Chapter
# junctions in between are never trimmed: they're already separated by $gap
# of pure digital silence (no click risk), and trimming there used to eat the
# first syllable of the next chapter (issue #4). Every chapter still gets
# resampled/reformatted so the concat segments match.
$conv     = "aresample=$sr,aformat=channel_layouts=$cl"
$headOpts = "start_periods=1:start_threshold=${headDb}dB:start_silence=${headWin}:detection=${det}"
$tailOpts = "start_periods=1:start_threshold=${tailDb}dB:start_silence=${tailWin}:detection=${det}"
$trimHead = "$conv,silenceremove=$headOpts,apad=pad_dur=$pad"                                        # trims the start only
$trimTail = "$conv,areverse,silenceremove=$tailOpts,areverse,apad=pad_dur=$pad"                       # trims the end only
$trimBoth = "$conv,silenceremove=$headOpts,areverse,silenceremove=$tailOpts,areverse,apad=pad_dur=$pad"  # single-chapter story: both edges are external

function ChapterFilter([int]$i, [int]$n) {
    if     ($n -eq 1)      { $trimBoth }   # only chapter -> both its edges are external
    elseif ($i -eq 0)      { $trimHead }   # first chapter -> only its START is external
    elseif ($i -eq $n - 1) { $trimTail }   # last chapter -> only its END is external
    else                   { $conv }       # inner chapter -> no external edge, no trim
}

# ---- previous layout (for the reconcile cache) -----------------------------
$prev = @{}
$prevJson = Join-Path $build 'stories_tree.json'
if ((Test-Path -LiteralPath $prevJson) -and -not $Rebuild) {
    foreach ($p in (Get-Content -LiteralPath $prevJson -Raw | ConvertFrom-Json)) { $prev[$p.key] = $p }
    Write-Host ("reconcile : {0} histoires deja fusionnees" -f $prev.Count)
} elseif ($Rebuild) {
    Write-Host "-Rebuild : re-fusion complete (+ purge des backups loudness)"
    if (Test-Path -LiteralPath $rawDir) { Remove-Item -LiteralPath $rawDir -Recurse -Force }
}

New-Item -ItemType Directory -Force -Path $menu | Out-Null

@{
  title = $Cfg.title
  description = $Cfg.description
  format = 'v1'; version = 1; nightModeAvailable = [bool]$Cfg.nightModeAvailable
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $tree 'metadata.json') -Encoding UTF8

$stories = Get-Content -LiteralPath (Join-Path $build 'stories.json') -Raw | ConvertFrom-Json

$idx = @{}
$targets = [System.Collections.Generic.HashSet[string]]::new()
$reused = 0; $merged = 0

$map = foreach ($st in $stories) {
    $cat = $st.category
    $slot = if ($flat -or -not $cat) { '(racine)' } else { $cat }
    $catDir = if ($flat -or -not $cat) { $menu } else { Join-Path $menu $cat }
    if (-not $idx.ContainsKey($slot)) { $idx[$slot] = 0 }
    $idx[$slot]++
    New-Item -ItemType Directory -Force -Path $catDir | Out-Null

    $fname  = '{0:D2} {1}' -f $idx[$slot], (Slug $st.title)   # on-disk name (human readable)
    $outMp3  = Join-Path $catDir "$fname.$storyExt"
    $outItem = Join-Path $catDir "$fname.item.mp3"
    $outPng  = Join-Path $catDir "$fname.item.png"
    [void]$targets.Add($outMp3); [void]$targets.Add($outItem); [void]$targets.Add($outPng)

    $chapPaths = @($st.chapters | ForEach-Object { Join-Path $src $_ })
    $p = $prev[$st.key]
    $prevMp3 = if ($p) { Resolve-TreePath $p.story_mp3 } else { $null }
    $reuse = $p -and (Test-Path -LiteralPath $prevMp3)
    if ($reuse) {
        foreach ($pair in @(@($p.story_mp3, $outMp3), @($p.item_mp3, $outItem), @($p.item_png, $outPng))) {
            $fromAbs = Resolve-TreePath $pair[0]
            MoveIfNeeded $fromAbs $pair[1]
            MoveIfNeeded (Join-Path $rawDir (BakName $fromAbs)) (Join-Path $rawDir (BakName $pair[1]))
        }
        $reused++
    }
    else {
        $n = $chapPaths.Count
        $parts = @("[0:a]$(ChapterFilter 0 $n)[c0]")
        $seq   = @('[lead]', '[c0]')
        for ($i = 1; $i -lt $n; $i++) {
            $parts += "[$i`:a]$(ChapterFilter $i $n)[c$i]"
            $seq   += @("[gap$i]", "[c$i]")
        }
        $seq += '[tail]'
        $parts += "anullsrc=r=$sr`:cl=$cl`:d=$lead[lead]"
        $parts += "anullsrc=r=$sr`:cl=$cl`:d=$tail[tail]"
        for ($i = 1; $i -lt $chapPaths.Count; $i++) {
            $parts += "anullsrc=r=$sr`:cl=$cl`:d=$gap[gap$i]"
        }
        $fc = ($parts -join ';') + ';' + ($seq -join '') + "concat=n=$($seq.Count)`:v=0:a=1[out]"
        $ffArgs = [System.Collections.Generic.List[string]]::new()
        $ffArgs.AddRange([string[]]@('-hide_banner','-loglevel','error','-y'))
        foreach ($cp in $chapPaths) { $ffArgs.Add('-i'); $ffArgs.Add([string]$cp) }
        $ffArgs.AddRange([string[]]@(
            '-filter_complex', $fc, '-map', '[out]',
            '-ar',"$sr",'-ac',"$ch",'-c:a',$Cfg.audio.codec,'-b:a',$Cfg.audio.bitrate,'-map_metadata','-1', $outMp3))
        & $ffmpeg $ffArgs.ToArray()
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed for $($st.title)" }
        $merged++
    }

    Write-Host ("  {0,-26} {1,-34} {2}" -f $slot, $fname, $(if ($reuse) {'(reuse)'} else {'(merge)'}))
    [pscustomobject]@{
        key = $st.key; title = $st.title; category = $cat
        base = $st.slug            # STABLE key for title_windows.csv / cover_tune.csv
        story_mp3 = ToTreeRelative $outMp3   # relative to $tree -- portable across machines
        item_mp3  = ToTreeRelative $outItem
        item_png  = ToTreeRelative $outPng
        chapter1  = [string]$chapPaths[0]
    }
}

# ---- drop orphans left by moves (files no longer in the target set) --------
Get-ChildItem -LiteralPath $menu -Recurse -File | Where-Object {
    $_.Name -notlike '0-item.*' -and -not $targets.Contains($_.FullName)
} | ForEach-Object { Write-Host "  orphelin supprime: $($_.FullName.Substring($menu.Length+1))"; Remove-Item -LiteralPath $_.FullName -Force }

$map | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $prevJson -Encoding UTF8
Write-Host ("`nOK - {0} histoires : {1} reutilisees, {2} (re)fusionnees -> {3}" -f $map.Count, $reused, $merged, $tree)
