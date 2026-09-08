<#
  05_run_spg.ps1
  Run studio-pack-generator on the prepared tree to build the Lunii pack .zip.
  We always provide the normalised story/menu audio, so audio conversion and
  audio-item generation are always skipped. Image flags are derived: when this
  project produces its own screen images (icons / covers / pack cover) SPG's
  image-item generation is skipped too; otherwise SPG renders its own text images.
  The SPG binary is auto-discovered (config tools.spg, else PATH -- any platform
  suffix). --lang and the final zip name come from project.json.
#>
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_config.ps1"
$build = $Cfg.build; $tree = $Cfg.tree
$spg = Assert-Tool $Cfg.spg 'studio-pack-generator'

$haveImages = ($Cfg.icons.mode -ne 'off') -or ($Cfg.covers.mode -ne 'off') -or ($Cfg.pack_cover.mode -ne 'none')

# clean previous SPG output if re-running (keep our provided .item.png / 0-item.png)
Get-ChildItem -LiteralPath $tree -Recurse -Filter '*-generated.item.png' -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath $build -Filter 'tree-*.zip' -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath $build -Filter 'story.json'  -ErrorAction SilentlyContinue | Remove-Item -Force

$spgArgs = [System.Collections.Generic.List[string]]::new()
$spgArgs.AddRange([string[]]@('--lang', $Cfg.lang, '--skip-wsl',
    '--skip-audio-convert', '--skip-image-convert', '--skip-audio-item-gen'))
if ($haveImages) {
    $spgArgs.AddRange([string[]]@('--skip-image-item-gen', '--skip-extract-image-from-mp-3'))
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
