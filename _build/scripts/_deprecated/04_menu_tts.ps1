<#
  04_menu_tts.ps1
  Generate the menu prompt audios (0-item.mp3) with Piper (fr_FR-siwis-medium):
   - pack cover, first menu, and the 9 category prompts.
  Output: raw 44.1kHz mono MP3 (loudness handled later by 04b_normalize).
#>
$ErrorActionPreference = 'Stop'
$src    = 'C:\Users\gia_a\Music\Timoté'
$build  = Join-Path $src '_build'
$menu   = Join-Path $build 'tree\Histoires de Timote'
$ffmpeg = 'C:\Program Files\ffmpeg\bin\ffmpeg.exe'
$uv     = 'C:\Users\gia_a\AppData\Local\Microsoft\WinGet\Packages\astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe\uv.exe'
$model  = Join-Path $build 'tools\piper\fr_FR-siwis-medium.onnx'
$work   = Join-Path $build 'work'

# folder (ASCII) -> spoken text (accented)
$catText = @{
  '1 Quotidien et autonomie' = "Le quotidien, et grandir tout seul."
  '2 Emotions et grandir'    = "Les émotions, et grandir."
  '3 Ecole'                  = "L'école."
  '4 Sorties et culture'     = "Les sorties, et la culture."
  '5 Voyages'                = "Les voyages."
  '6 Sport et plein air'     = "Le sport, et le plein air."
  '7 Fetes'                  = "Les fêtes."
  '8 Corps et sante'         = "Le corps, et la santé."
  '9 Nature et animaux'      = "La nature, et les animaux."
}

function Speak([string]$text, [string]$outMp3) {
    $wav = Join-Path $work ('tts_' + [IO.Path]::GetRandomFileName() + '.wav')
    $text | & $uv run --python 3.12 --with piper-tts python -m piper -m $model -f $wav
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $wav)) { throw "piper failed: $text" }
    New-Item -ItemType Directory -Force -Path (Split-Path $outMp3) | Out-Null
    & $ffmpeg -hide_banner -loglevel error -y `
        -f lavfi -i 'anullsrc=r=44100:cl=mono' -i $wav `
        -filter_complex '[1:a]aresample=44100,aformat=channel_layouts=mono[v];[0:a]atrim=0:0.15[l];[0:a]atrim=0:0.4[t];[l][v][t]concat=n=3:v=0:a=1[out]' `
        -map '[out]' -ar 44100 -ac 1 -c:a libmp3lame -b:a 192k -map_metadata -1 -- $outMp3
    Remove-Item -LiteralPath $wav -Force
    Write-Host "  $([IO.Path]::GetFileName($outMp3))  <-  $text"
}

Speak "Choisis une histoire de Timoté."      (Join-Path $build 'tree\0-item.mp3')
Speak "Choisis un thème."                     (Join-Path $menu '0-item.mp3')
foreach ($k in ($catText.Keys | Sort-Object)) {
    Speak $catText[$k] (Join-Path $menu "$k\0-item.mp3")
}
Write-Host "`nOK - 11 prompts de menu generes"
