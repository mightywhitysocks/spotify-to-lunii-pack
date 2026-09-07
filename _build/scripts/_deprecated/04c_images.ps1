<#
  04c_images.ps1
  Generate every 320x240 screen image with ffmpeg drawtext (accented French,
  consistent style) so SPG generates none:
   - tree\0-item.png                         pack cover
   - tree\Histoires de Timote\0-item.png     first menu
   - tree\...\<cat>\0-item.png   x9           category screens
   - tree\...\<cat>\<base>.item.png  x45      story title screens
#>
$ErrorActionPreference = 'Stop'
$build  = 'C:\Users\gia_a\Music\Timoté\_build'
$tree   = Join-Path $build 'tree'
$menu   = Join-Path $tree 'Histoires de Timote'
$ffmpeg = 'C:\Program Files\ffmpeg\bin\ffmpeg.exe'
$font   = 'C\:/Windows/Fonts/comicbd.ttf'      # ffmpeg drawtext path escaping
$work   = Join-Path $build 'work'

$catText = @{
  '1 Quotidien et autonomie' = 'Le quotidien'
  '2 Emotions et grandir'    = 'Les émotions'
  '3 Ecole'                  = "L'école"
  '4 Sorties et culture'     = 'Sorties & culture'
  '5 Voyages'                = 'Les voyages'
  '6 Sport et plein air'     = 'Sport & plein air'
  '7 Fetes'                  = 'Les fêtes'
  '8 Corps et sante'         = 'Corps & santé'
  '9 Nature et animaux'      = 'Nature & animaux'
}
# background tint per category (index 0 = cover/menu)
$bg = @('0x14202e','0x1d3b2a','0x3a1d2e','0x1d2f3b','0x30301d','0x1d3340',
        '0x3b2a1d','0x2e1d3b','0x1d3b33','0x331d1d')

function Wrap([string]$t, [int]$max) {
    $words = $t -split ' '; $lines = @(); $cur = ''
    foreach ($w in $words) {
        if ($cur -and ($cur.Length + 1 + $w.Length) -gt $max) { $lines += $cur; $cur = $w }
        else { $cur = if ($cur) { "$cur $w" } else { $w } }
    }
    if ($cur) { $lines += $cur }
    $lines
}

function Make([string]$text, [string]$out, [string]$bgcol, [int]$size) {
    $lines = Wrap $text 16
    if ($lines.Count -gt 3) { $lines = Wrap $text 22; $size = [int]($size * 0.82) }
    $n = $lines.Count
    $lh = $size + 12
    New-Item -ItemType Directory -Force -Path (Split-Path $out) | Out-Null
    $draws = for ($i = 0; $i -lt $n; $i++) {
        $tf = Join-Path $work ('txt_' + [IO.Path]::GetRandomFileName() + '.txt')
        [IO.File]::WriteAllText($tf, [string]$lines[$i], (New-Object Text.UTF8Encoding($false)))
        $tfEsc = ($tf -replace '\\', '/') -replace ':', '\:'
        $dy = "(h-$($n*$lh))/2 + $($i*$lh)"
        "drawtext=fontfile='$font':textfile='$tfEsc':fontcolor=0xF5F5F5:fontsize=$size" +
        ":x=(w-text_w)/2:y=$dy`:borderw=3:bordercolor=0x000000AA"
    }
    $vf = ($draws -join ',')
    & $ffmpeg -hide_banner -loglevel error -y -f lavfi -i "color=c=$bgcol`:s=320x240" `
        -vf $vf -frames:v 1 -- $out
    if ($LASTEXITCODE -ne 0) { throw "drawtext failed: $text" }
    Get-ChildItem -LiteralPath $work -Filter 'txt_*.txt' | Remove-Item -Force
    Write-Host "  $([IO.Path]::GetFileName((Split-Path $out -Parent)))/$([IO.Path]::GetFileName($out))  <-  $text"
}

Make 'Les histoires de Timoté' (Join-Path $tree '0-item.png') $bg[0] 30
Make 'Choisis un thème'        (Join-Path $menu '0-item.png') $bg[0] 34
foreach ($k in ($catText.Keys | Sort-Object)) {
    $i = [int]$k.Substring(0,1)
    Make $catText[$k] (Join-Path $menu "$k\0-item.png") $bg[$i] 34
}

$tr = Get-Content (Join-Path $build 'stories_tree.json') -Raw | ConvertFrom-Json
foreach ($m in $tr) {
    $i = [int]$m.category.Substring(0,1)
    Make $m.title $m.item_png $bg[$i] 30
}
Write-Host "`nOK - $(2 + 9 + $tr.Count) images generees"
