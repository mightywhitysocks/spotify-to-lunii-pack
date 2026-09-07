<#
  05_run_spg.ps1
  Run studio-pack-generator on the prepared tree to build the Lunii pack .zip.
  We provide all story/title/menu audio (normalised); SPG generates the title
  images from names, serialises story.json (flat stageNodes/actionNodes,
  format v1) and zips.  Story-end -> back to category menu is SPG's default.
#>
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_config.ps1"
$build = $Cfg.build; $tree = $Cfg.tree
$spg   = Join-Path $build 'tools\spg\Studio-Pack-Generator\studio-pack-generator-x86_64-windows.exe'

# clean previous SPG output if re-running (keep our provided .item.png / 0-item.png)
Get-ChildItem -LiteralPath $tree -Recurse -Filter '*-generated.item.png' -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath $build -Filter 'tree-*.zip' -ErrorAction SilentlyContinue | Remove-Item -Force
Get-ChildItem -LiteralPath $build -Filter 'story.json'  -ErrorAction SilentlyContinue | Remove-Item -Force

# we supply ALL assets (audio + images) already in Lunii format:
#   -v skip-audio-convert   -j skip-image-convert
#   -a skip-audio-item-gen  -i skip-image-item-gen   -m skip-extract-image-from-mp3
& $spg --lang fr --skip-wsl --skip-audio-convert --skip-image-convert `
       --skip-audio-item-gen --skip-image-item-gen --skip-extract-image-from-mp-3 `
       --output-folder $build -- $tree
if ($LASTEXITCODE -ne 0) { throw "SPG exit $LASTEXITCODE" }

$zip = Get-ChildItem -LiteralPath $build -Filter 'tree-*.zip' | Sort-Object LastWriteTime | Select-Object -Last 1
if (-not $zip) { throw "pas de zip produit" }
$final = Join-Path $build 'Les histoires de Timoté.zip'
Move-Item -LiteralPath $zip.FullName -Destination $final -Force
Write-Host "`nOK -> $final  ($([math]::Round((Get-Item $final).Length/1MB,1)) MB)"
