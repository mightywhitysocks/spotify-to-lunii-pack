<#
  02_merge.ps1
  Build the SPG folder tree: one 44.1kHz mono MP3 per story (chapters merged,
  edge-silence trimmed, 0.8s between chapters, small guard silence).
  No loudness change here (done in 04b_normalize).

  RECONCILE (not wipe): the story audio only depends on the source chapters,
  never on the category. So a re-run re-uses every merged clip that already
  exists and just MOVES it to its (possibly new) category / index slot -- and
  moves its .item.mp3 / .item.png / loudness backup with it. Only genuinely new
  stories are re-encoded. -Rebuild forces a full re-merge.

  The JSON `base` is now the STABLE slug (timote-...), independent of category,
  so title_windows.csv / cover_tune.csv keys survive a recategorisation.
  Outputs: _build\tree\... , _build\stories_tree.json
#>
param([switch]$Rebuild)
$ErrorActionPreference = 'Stop'
[Threading.Thread]::CurrentThread.CurrentCulture = 'en-US'
. "$PSScriptRoot\_config.ps1"
$src = $Cfg.src; $build = $Cfg.build; $tree = $Cfg.tree; $ffmpeg = $Cfg.ffmpeg
$menu   = Join-Path $tree 'Histoires de Timote'
$rawDir = $Cfg.rawAudio

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

# each chapter: to 44.1k mono first (so concat segments match), then trim both edges
$trim = "aresample=44100,aformat=channel_layouts=mono," +
        "silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05," +
        "areverse,silenceremove=start_periods=1:start_threshold=-50dB:start_silence=0.05,areverse"

# ---- previous layout (for the reconcile cache) -----------------------------
$prev = @{}
$prevJson = Join-Path $build 'stories_tree.json'
if ((Test-Path -LiteralPath $prevJson) -and -not $Rebuild) {
    foreach ($p in (Get-Content -LiteralPath $prevJson -Raw | ConvertFrom-Json)) { $prev[$p.key] = $p }
    Write-Host ("reconcile : {0} histoires deja fusionnees" -f $prev.Count)
} elseif ($Rebuild) {
    # re-fusion complete -> every pristine loudness backup is now stale
    Write-Host "-Rebuild : re-fusion complete (+ purge des backups loudness)"
    if (Test-Path -LiteralPath $rawDir) { Remove-Item -LiteralPath $rawDir -Recurse -Force }
}

New-Item -ItemType Directory -Force -Path $menu | Out-Null

@{
  title = 'Les histoires de Timoté'
  description = 'Pack perso - histoires Timoté (audiolivres Gründ)'
  format = 'v1'; version = 1; nightModeAvailable = $false
} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $tree 'metadata.json') -Encoding UTF8

$stories = Get-Content -LiteralPath (Join-Path $build 'stories.json') -Raw | ConvertFrom-Json

$idx = @{}
$targets = [System.Collections.Generic.HashSet[string]]::new()
$reused = 0; $merged = 0

$map = foreach ($st in $stories) {
    $cat = $st.category
    if (-not $idx.ContainsKey($cat)) { $idx[$cat] = 0 }
    $idx[$cat]++
    $catDir = Join-Path $menu $cat
    New-Item -ItemType Directory -Force -Path $catDir | Out-Null

    $fname  = '{0:D2} {1}' -f $idx[$cat], (Slug $st.title)   # on-disk name (human readable)
    $outMp3  = Join-Path $catDir "$fname.mp3"
    $outItem = Join-Path $catDir "$fname.item.mp3"
    $outPng  = Join-Path $catDir "$fname.item.png"
    [void]$targets.Add($outMp3); [void]$targets.Add($outItem); [void]$targets.Add($outPng)

    $chapPaths = @($st.chapters | ForEach-Object { Join-Path $src $_ })
    $p = $prev[$st.key]
    $reuse = $p -and (Test-Path -LiteralPath $p.story_mp3)
    if ($reuse) {
        # re-use the already-merged (and normalised) audio: move each file, plus its
        # pristine loudness backup, into the new slot so 04b stays idempotent.
        foreach ($pair in @(@($p.story_mp3, $outMp3), @($p.item_mp3, $outItem), @($p.item_png, $outPng))) {
            MoveIfNeeded $pair[0] $pair[1]
            MoveIfNeeded (Join-Path $rawDir (BakName $pair[0])) (Join-Path $rawDir (BakName $pair[1]))
        }
        $reused++
    }
    else {
        $parts = @("[0:a]$trim[c0]")
        $seq   = @('[lead]', '[c0]')
        for ($i = 1; $i -lt $chapPaths.Count; $i++) {
            $parts += "[$i`:a]$trim[c$i]"
            $seq   += @("[gap$i]", "[c$i]")
        }
        $seq += '[tail]'
        $parts += "anullsrc=r=44100:cl=mono:d=0.3[lead]"
        $parts += "anullsrc=r=44100:cl=mono:d=0.6[tail]"
        for ($i = 1; $i -lt $chapPaths.Count; $i++) {
            $parts += "anullsrc=r=44100:cl=mono:d=0.8[gap$i]"
        }
        $fc = ($parts -join ';') + ';' + ($seq -join '') + "concat=n=$($seq.Count)`:v=0:a=1[out]"
        $ffArgs = [System.Collections.Generic.List[string]]::new()
        $ffArgs.AddRange([string[]]@('-hide_banner','-loglevel','error','-y'))
        foreach ($cp in $chapPaths) { $ffArgs.Add('-i'); $ffArgs.Add([string]$cp) }
        $ffArgs.AddRange([string[]]@(
            '-filter_complex', $fc, '-map', '[out]',
            '-ar','44100','-ac','1','-c:a','libmp3lame','-b:a','256k','-map_metadata','-1', $outMp3))
        & $ffmpeg $ffArgs.ToArray()
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed for $($st.title)" }
        $merged++
    }

    Write-Host ("  {0,-26} {1,-34} {2}" -f $cat.Substring(2), $fname, $(if ($reuse) {'(reuse)'} else {'(merge)'}))
    [pscustomobject]@{
        key = $st.key; title = $st.title; category = $cat
        base = $st.slug            # STABLE key for title_windows.csv / cover_tune.csv
        story_mp3 = $outMp3
        item_mp3  = $outItem
        item_png  = $outPng
        chapter1  = [string]$chapPaths[0]
    }
}

# ---- drop orphans left by moves (files no longer in the target set) --------
Get-ChildItem -LiteralPath $menu -Recurse -File | Where-Object {
    $_.Name -notlike '0-item.*' -and -not $targets.Contains($_.FullName)
} | ForEach-Object { Write-Host "  orphelin supprime: $($_.FullName.Substring($menu.Length+1))"; Remove-Item -LiteralPath $_.FullName -Force }

$map | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $prevJson -Encoding UTF8
Write-Host ("`nOK - {0} histoires : {1} reutilisees, {2} (re)fusionnees -> {3}" -f $map.Count, $reused, $merged, $tree)
