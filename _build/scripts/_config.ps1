<#
  _config.ps1 -- config loader for the pack build scripts (single source of truth).

  Dot-source at the top of every *.ps1:   . "$PSScriptRoot\_config.ps1"

  Locates the project file (env PACK_CONFIG wins, else _build\project.json),
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
    merge  = @{ lead = 0.3; tail = 0.6; gap = 0.8; trim_silence_db = -50 }
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
                clip_bitrate = '192k'; lead = 0.15; fade_out = 0.26; vad_l = 0.40; vad_r = 0.28 }
    icons  = @{ mode = 'off'; set = 'black';
                url = 'https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/{set}/svg/{code}.svg';
                render_bg = '0xF6F3EC' }
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

# ---- load + merge --------------------------------------------------------
$cfgPath = if ($env:PACK_CONFIG) { $env:PACK_CONFIG } else { Join-Path $BuildDir 'project.json' }
$user = @{}
if (Test-Path -LiteralPath $cfgPath) {
    $user = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json -AsHashtable
}
$Cfg = Merge-Config $Defaults $user
if (-not $Cfg.menu_root_name) { $Cfg.menu_root_name = ConvertTo-Slug $Cfg.title }

# ---- tool resolution ----------------------------------------------------
function Resolve-Tool($value, [string[]]$names) {
    if ($value) {
        $p = if ([IO.Path]::IsPathRooted($value)) { $value } else { Join-Path $BuildDir $value }
        return $p
    }
    foreach ($n in $names) {
        $g = Get-Command $n -ErrorAction SilentlyContinue
        if ($g) { return $g.Source }
    }
    return $null
}
function Assert-Tool($path, [string]$label) {
    if (-not $path -or -not (Test-Path -LiteralPath $path)) {
        $g = if ($path) { Get-Command $path -ErrorAction SilentlyContinue } else { $null }
        if (-not $g) {
            throw "$label introuvable ($path). Renseigne tools dans $cfgPath ou ajoute $label au PATH."
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
# JSON stores the Python-style named groups (?P<name>); .NET wants (?<name>)
$Cfg.filenamePatternNet = $Cfg.filename_pattern -replace '\(\?P<', '(?<'

# key of a tree audio file in work\raw_audio: "<parent dir>__<file name>".
# Mirror of bak_name() in _config.py -- keep the two in sync.
function BakName([string]$fullPath) {
    (Split-Path (Split-Path $fullPath -Parent) -Leaf) + '__' + (Split-Path $fullPath -Leaf)
}

# regex-escaped alternation of the configured source extensions, e.g. 'mp3|m4a|flac'
function SourceExtRegex { ($Cfg.source_ext | ForEach-Object { [regex]::Escape($_) }) -join '|' }
function Test-SourceFile([string]$name) {
    $ext = [IO.Path]::GetExtension($name).TrimStart('.').ToLower()
    $Cfg.source_ext -contains $ext
}
