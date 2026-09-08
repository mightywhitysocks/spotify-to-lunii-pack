<#
  05_run_spg.ps1
  Run studio-pack-generator on the prepared tree to build the Lunii pack .zip.
  We always provide the normalised story/menu audio, so audio conversion and
  audio-item generation are always skipped. Image flags are derived: when this
  project produces its own screen images (icons / covers / pack cover) SPG's
  image-item generation is skipped too; otherwise SPG renders its own text images.
  Exception: when icons are on but 07_icons.py's report (work\icons_report.json)
  says coverage is incomplete -- or the report is missing -- SPG's image-item
  generation is left ON so it renders a fallback text screen for every gap.
  Without this a story whose OpenMoji code is absent or failed to download would
  ship with no image at all on a cold-start build (02_merge.ps1 never creates an
  item.png). In that degraded path SPG also regenerates any intentionally-removed
  menu image (e.g. first_menu_audio_only) -- fix the missing icon to avoid it.
  The SPG binary is auto-discovered (config tools.spg, else PATH -- any platform
  suffix). --lang and the final zip name come from project.json.
#>
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_config.ps1"
$build = $Cfg.build; $tree = $Cfg.tree
$spg = Assert-Tool $Cfg.spg 'studio-pack-generator'

$haveImages = ($Cfg.icons.mode -ne 'off') -or ($Cfg.covers.mode -ne 'off') -or ($Cfg.pack_cover.mode -ne 'none')

# Only trust "we produced every screen image" (and let SPG skip its own text-image
# generation) if 07_icons.py confirmed 100% icon coverage. Missing report == not run.
$iconsComplete = $true
if ($Cfg.icons.mode -ne 'off') {
    $iconsReport = Join-Path $build 'work\icons_report.json'
    if (Test-Path -LiteralPath $iconsReport) {
        $iconsComplete = [bool]((Get-Content -LiteralPath $iconsReport -Raw | ConvertFrom-Json).complete)
        if (-not $iconsComplete) {
            Write-Host "icons_report.json : icones incompletes -> SPG generera les ecrans texte manquants"
        }
    } else {
        $iconsComplete = $false
        Write-Host "work\icons_report.json absent (07_icons.py pas lance ?) -> SPG generera les ecrans texte manquants"
    }
}

# clean previous SPG output if re-running (keep our provided .item.png / 0-item.png)
Get-ChildItem -LiteralPath $tree -Recurse -Filter '*-generated.item.png' -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath $build -Filter 'tree-*.zip' -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath $build -Filter 'story.json'  -ErrorAction SilentlyContinue | Remove-Item -Force

$spgArgs = [System.Collections.Generic.List[string]]::new()
$spgArgs.AddRange([string[]]@('--lang', $Cfg.lang, '--skip-wsl',
    '--skip-audio-convert', '--skip-image-convert', '--skip-audio-item-gen'))
if ($haveImages) {
    $spgArgs.Add('--skip-extract-image-from-mp-3')
    if ($iconsComplete) { $spgArgs.Add('--skip-image-item-gen') }
}
$spgArgs.AddRange([string[]]@('--output-folder', $build, '--', $tree))

& $spg $spgArgs.ToArray()
if ($LASTEXITCODE -ne 0) { throw "SPG exit $LASTEXITCODE" }

$zip = Get-ChildItem -LiteralPath $build -Filter 'tree-*.zip' | Sort-Object LastWriteTime | Select-Object -Last 1
if (-not $zip) { throw "pas de zip produit" }
$safe = ($Cfg.title -replace '[<>:"/\\|?*]', ' ').Trim()
$final = Join-Path $build "$safe.zip"
Move-Item -LiteralPath $zip.FullName -Destination $final -Force
Write-Host "`nOK -> $final  ($([math]::Round((Get-Item $final).Length/1MB,1)) MB)"
