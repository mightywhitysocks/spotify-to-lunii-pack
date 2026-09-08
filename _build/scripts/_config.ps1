<#
  _config.ps1 -- config loader for the pack build scripts (single source of truth).

  Dot-source at the top of every *.ps1:   . "$PSScriptRoot\_config.ps1"

  Locates the project file (env PACK_CONFIG wins, else the gitignored
  _build\project.json, else the committed _build\project.example.json),
  deep-merges it over the built-in DEFAULTS, resolves every tool path
  (config value -> else Get-Command on PATH -> else a clear error), and exposes
  a single $Cfg hashtable. The whole merged config is on $Cfg (e.g.
  $Cfg.title, $Cfg.audio.sample_rate, $Cfg.categories); the legacy path names
  ($Cfg.src / $Cfg.build / $Cfg.tree / $Cfg.rawAudio / $Cfg.ffmpeg /
  $Cfg.ffprobe / $Cfg.uv / $Cfg.spg / $Cfg.menu) are derived from it so old
  scripts keep working.
#>
$ErrorActionPreference = 'Stop'

$script:BuildDir = Split-Path $PSScriptRoot -Parent      # ...\<project>\_build
$script:TreeDir  = Join-Path $BuildDir 'tree'

function ConvertTo-Slug([string]$s) {
    $n = $s.Normalize([Text.NormalizationForm]::FormD)
    $a = -join ($n.ToCharArray() | Where-Object {
        [Globalization.CharUnicodeInfo]::GetUnicodeCategory($_) -ne 'NonSpacingMark' })
    ($a -replace "[^A-Za-z0-9]+", " ").Trim()
}

function Merge-Config($base, $over) {
    # recursively merge $over onto a copy of $base; hashtables merge, everything
    # else (arrays, scalars) replaces. Mirror of _deep_merge in _config.py.
    if ($base -is [hashtable] -and $over -is [hashtable]) {
        $out = @{}
        foreach ($k in $base.Keys) { $out[$k] = $base[$k] }
        foreach ($k in $over.Keys) {
            $out[$k] = if ($base.ContainsKey($k)) { Merge-Config $base[$k] $over[$k] } else { $over[$k] }
        }
        return $out
    }
    return $over
}

$Defaults = @{
    title              = 'Mon pack'
    description        = ''
    lang               = 'fr'
    nightModeAvailable = $false
    source_dir         = '..'
    source_ext         = @('mp3','m4a','m4b','flac','ogg','opus','wav','mp4','m4v','mkv','mov','avi','webm')
    menu_root_name     = ''
    slug_prefix        = ''
    audio  = @{ sample_rate = 44100; channels = 1; codec = 'libmp3lame'; bitrate = '256k'; target_lufs = -16; target_tp = -1.5 }
    merge  = @{ lead = 0.3; tail = 0.6; gap = 0.8;
                trim_head_db = -45; trim_head_window = 0.3;
                trim_tail_db = -45; trim_tail_window = 0.3;
                trim_detection = 'rms'; trim_pad = 0.1 }
    filename_pattern       = '^(?<num>\d+)[\s._-]+(?<title>.+)$'
    num_group              = 'num'
    chapter_group          = 'chapter'
    title_group            = 'title'
    story_key_strip_prefix = ''
    discard                = @{}
    categories             = @()
    uncategorized_name     = 'Divers'
    story_icons            = @{}
    menu_prompts           = @{ root = ''; category_chooser = '' }
    first_menu_audio_only  = $false
    titles = @{ mode = 'off'; fuzzy_first_word = $false; synonyms = @{}; strip_key_word = '';
                clip_bitrate = '192k'; lead = 0.15; fade_out = 0.26; vad_l = 0.40; vad_r = 0.28;
                trim_head_db = -48; trim_head_window = 0.18;
                trim_tail_db = -45; trim_tail_window = 0.08;
                trim_detection = 'peak'; trim_pad = 0.14 }
    icons  = @{ mode = 'off'; set = 'black';
                url = 'https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/{set}/svg/{code}.svg';
                render_bg = '0xF6F3EC'; sources = @{} }
    covers = @{ mode = 'off'; bad_album = ''; good_artist = ''; crop_top = 0.30; crop_bottom = 0.16 }
    pack_cover = @{ mode = 'none'; src = ''; bg = 'srgb(52,60,132)'; fuzz = '22%' }
    image  = @{ canvas = '#0A0D12'; w = 320; h = 240; fit = 232 }
    tts    = @{ engine = 'piper'; model = ''; lead = 0.15; tail = 0.4 }
    tools  = @{ ffmpeg = ''; ffprobe = ''; uv = ''; spg = ''; imagemagick = '' }
}

$SpgNames = @(
    'studio-pack-generator',
    'studio-pack-generator-x86_64-windows.exe', 'studio-pack-generator-x86_64-windows',
    'studio-pack-generator-x86_64-linux', 'studio-pack-generator-aarch64-linux',
    'studio-pack-generator-x86_64-macos', 'studio-pack-generator-aarch64-macos'
)

# <section>.<key> -> allowed values. A typo (mode: "detetc") otherwise silently
# no-ops a whole stage. Mirror of _MODE_ENUMS in _config.py -- keep in sync.
$ModeEnums = @{
    'titles.mode'     = @('detect', 'off')
    'icons.mode'      = @('emoji', 'off')
    'covers.mode'     = @('spotify', 'off')
    'pack_cover.mode' = @('none', 'image', 'floodfill')
    'tts.engine'      = @('piper')
}
$FreeformKeys = @('discard', 'story_icons', 'synonyms', 'sources')   # user data, not schema

function Get-UnknownKeys($user, $defaults, [string]$prefix = '') {
    if ($user -isnot [hashtable] -or $defaults -isnot [hashtable]) { return @() }
    $out = @()
    foreach ($k in $user.Keys) {
        $path = "$prefix$k"
        if (-not $defaults.ContainsKey($k)) { $out += $path }
        elseif ($FreeformKeys -notcontains $k) {
            $out += Get-UnknownKeys $user[$k] $defaults[$k] "$path."
        }
    }
    return $out
}

function Assert-ConfigValid($cfg, $raw, [string]$srcName) {
    $bad = @()
    foreach ($kv in $ModeEnums.GetEnumerator()) {
        $s, $key = $kv.Key -split '\.', 2
        $val = if ($cfg[$s] -is [hashtable]) { $cfg[$s][$key] } else { $null }
        if ($kv.Value -notcontains $val) {
            $bad += "$($kv.Key) = '$val' (attendu : $($kv.Value -join ', '))"
        }
    }
    # a single-element JSON array comes back unwrapped from ConvertFrom-Json, so
    # only the unambiguous mistake (an object where a list is expected) is caught.
    foreach ($k in @('categories', 'source_ext')) {
        if ($cfg[$k] -is [hashtable]) { $bad += "$k doit etre une liste JSON, pas un objet" }
    }
    if ($bad) {
        throw "project.json invalide ($srcName) :`n  - " + ($bad -join "`n  - ")
    }
    foreach ($path in (Get-UnknownKeys $raw $Defaults)) {
        Write-Warning "project.json : cle inconnue ignoree -> $path"
    }
}

# ---- load + merge --------------------------------------------------------
# PACK_CONFIG wins; else project.json (gitignored -- the active pack); else the
# committed generic example, so a fresh checkout still loads. The Timoté
# reference config is _build\examples\timote.json -- copy it onto project.json.
$cfgPath = if ($env:PACK_CONFIG) { $env:PACK_CONFIG }
           elseif (Test-Path -LiteralPath (Join-Path $BuildDir 'project.json')) { Join-Path $BuildDir 'project.json' }
           else { Join-Path $BuildDir 'project.example.json' }
$user = @{}
if (Test-Path -LiteralPath $cfgPath) {
    $user = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json -AsHashtable
}
$Cfg = Merge-Config $Defaults $user

# machine-specific overrides (tool paths, ...) -- gitignored, never committed,
# always at _build\project.local.json regardless of PACK_CONFIG. See
# project.local.json.example. Mirror of _config.py -- keep the two in sync.
$localCfgPath = Join-Path $BuildDir 'project.local.json'
$raw = $user
if (Test-Path -LiteralPath $localCfgPath) {
    $local = Get-Content -LiteralPath $localCfgPath -Raw | ConvertFrom-Json -AsHashtable
    $Cfg = Merge-Config $Cfg $local
    $raw = Merge-Config $raw $local
}
Assert-ConfigValid $Cfg $raw (Split-Path $cfgPath -Leaf)
if (-not $Cfg.menu_root_name) { $Cfg.menu_root_name = ConvertTo-Slug $Cfg.title }

# ---- tool resolution ----------------------------------------------------
# vendored, unpacked binaries that were never added to PATH (see
# project.local.json.example): scan _build\tools\** for a known name.
# Mirror of _find_vendored in _config.py -- keep the two in sync.
function Find-VendoredTool([string[]]$names) {
    $toolsDir = Join-Path $BuildDir 'tools'
    if (-not (Test-Path -LiteralPath $toolsDir)) { return $null }
    $want = [Collections.Generic.HashSet[string]]::new(
        [string[]]$names, [StringComparer]::OrdinalIgnoreCase)
    $hit = Get-ChildItem -LiteralPath $toolsDir -Recurse -File -ErrorAction SilentlyContinue |
           Where-Object { $want.Contains($_.Name) } |
           Sort-Object FullName | Select-Object -First 1
    if ($hit) { return $hit.FullName }
    return $null
}
function Resolve-Tool($value, [string[]]$names) {
    if ($value) {
        $p = if ([IO.Path]::IsPathRooted($value)) { $value } else { Join-Path $BuildDir $value }
        return $p
    }
    foreach ($n in $names) {
        $g = Get-Command $n -ErrorAction SilentlyContinue
        if ($g) { return $g.Source }
    }
    return (Find-VendoredTool $names)
}
function Assert-Tool($path, [string]$label) {
    if (-not $path -or -not (Test-Path -LiteralPath $path)) {
        $g = if ($path) { Get-Command $path -ErrorAction SilentlyContinue } else { $null }
        if (-not $g) {
            throw "$label introuvable ($path). Renseigne tools dans $localCfgPath (voir project.local.json.example) ou ajoute $label au PATH."
        }
    }
    return $path
}

$ffmpeg  = Resolve-Tool $Cfg.tools.ffmpeg  @('ffmpeg')
$ffprobe = if ($Cfg.tools.ffprobe) { Resolve-Tool $Cfg.tools.ffprobe @('ffprobe') }
           elseif ($Cfg.tools.ffmpeg) { ($ffmpeg -replace 'ffmpeg', 'ffprobe') }
           else { Resolve-Tool '' @('ffprobe') }
$uv  = Resolve-Tool $Cfg.tools.uv  @('uv')
$spg = Resolve-Tool $Cfg.tools.spg $SpgNames
$im  = Resolve-Tool $Cfg.tools.imagemagick @('magick','convert')

# ---- derived legacy properties ----------------------------------------
$srcDir = [IO.Path]::GetFullPath((Join-Path $BuildDir $Cfg.source_dir))
$Cfg.src      = $srcDir
$Cfg.build    = $BuildDir
$Cfg.tree     = $TreeDir
$Cfg.menuRoot = $Cfg.menu_root_name
$Cfg.menu     = Join-Path $TreeDir $Cfg.menu_root_name
$Cfg.rawAudio = Join-Path $BuildDir 'work\raw_audio'
$Cfg.ffmpeg   = $ffmpeg
$Cfg.ffprobe  = $ffprobe
$Cfg.uv       = $uv
$Cfg.spg      = $spg
$Cfg.im       = $im
$Cfg.configPath = $cfgPath
$Cfg.localConfigPath = $localCfgPath
# JSON stores the Python-style named groups (?P<name>); .NET wants (?<name>)
$Cfg.filenamePatternNet = $Cfg.filename_pattern -replace '\(\?P<', '(?<'

# key of a tree audio file in work\raw_audio: "<parent dir>__<file name>".
# Mirror of bak_name() in _config.py -- keep the two in sync.
function BakName([string]$fullPath) {
    (Split-Path (Split-Path $fullPath -Parent) -Leaf) + '__' + (Split-Path $fullPath -Leaf)
}

# Re-anchor a path stored in stories_tree.json under the local tree dir.
# 02_merge.ps1 now writes story_mp3/item_mp3/item_png relative to $Cfg.tree,
# but stories_tree.json produced by an older version of the script (or moved
# from another machine) can still hold an absolute path, Windows backslashes
# included. Keep only the portion after the 'tree' folder segment when present
# (that folder's own fixed name), and rebuild it under the local tree -- a
# purely relative path has no such segment and is joined onto the tree as-is.
# Mirror of resolve_tree_path() in _config.py -- keep the two in sync.
function Resolve-TreePath([string]$raw) {
    $parts = [regex]::Split($raw, '[\\/]+') | Where-Object { $_ -ne '' }
    $i = [array]::IndexOf($parts, 'tree')
    if ($i -ge 0) {
        $rest = @()
        for ($j = $i + 1; $j -lt $parts.Count; $j++) { $rest += $parts[$j] }
        $parts = $rest
    }
    $p = $Cfg.tree
    foreach ($seg in $parts) { $p = Join-Path $p $seg }
    return $p
}

# Single ffmpeg EBU R128 pass over one file -> integrated loudness + true peak.
# The one measurement path for 01_inventory / 04b_normalize / 04d_report -- keep
# it here so a change to the filter or the parse lands everywhere at once.
# Caller must have asserted $Cfg.ffmpeg (Assert-Tool). $layout: 'mono' | 'stereo'.
function Measure-Loudness([string]$path, [string]$layout = 'mono') {
    $o = (& $Cfg.ffmpeg -hide_banner -nostats -i $path -map 0:a:0 `
          -af "aformat=channel_layouts=$layout,ebur128=peak=true:framelog=quiet" `
          -f null - 2>&1) -join "`n"
    $sum = ($o -split 'Summary:')[-1]
    $I  = if ($sum -match 'I:\s*(-?[\d.]+)\s*LUFS')    { [double]$Matches[1] } else { $null }
    $TP = if ($sum -match 'Peak:\s*(-?[\d.]+)\s*dBFS') { [double]$Matches[1] } else { $null }
    [pscustomobject]@{ lufs = $I; peak = $TP }
}

# regex-escaped alternation of the configured source extensions, e.g. 'mp3|m4a|flac'
function SourceExtRegex { ($Cfg.source_ext | ForEach-Object { [regex]::Escape($_) }) -join '|' }
function Test-SourceFile([string]$name) {
    $ext = [IO.Path]::GetExtension($name).TrimStart('.').ToLower()
    $Cfg.source_ext -contains $ext
}
