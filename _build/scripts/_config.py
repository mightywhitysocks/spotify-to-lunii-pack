"""Shared paths for the Timoté build scripts (single source of truth).

Import from any script in this folder:  from _config import BUILD, FFMPEG, ...
"""
from pathlib import Path

BUILD = Path(__file__).resolve().parent.parent          # ...\Timoté\_build
SRC = BUILD.parent                                       # ...\Timoté  (the 99 source MP3s)
TREE = BUILD / "tree"

FFMPEG = r"C:\Program Files\ffmpeg\bin\ffmpeg.exe"
FFPROBE = FFMPEG.replace("ffmpeg.exe", "ffprobe.exe")
UV = (r"C:\Users\gia_a\AppData\Local\Microsoft\WinGet\Packages"
      r"\astral-sh.uv_Microsoft.Winget.Source_8wekyb3d8bbwe\uv.exe")
IM = str(BUILD / "tools" / "spg" / "Studio-Pack-Generator" / "tools" / "convert.exe")

CANVAS = "#0A0D12"                 # near-black Lunii screen background (all image scripts)
RAW_AUDIO = BUILD / "work" / "raw_audio"   # 04b_normalize's pristine loudness backups


def bak_name(p) -> str:
    """key of a tree audio file in RAW_AUDIO: '<parent dir>__<file name>'.
    Mirror of BakName in _config.ps1 -- keep the two in sync."""
    from pathlib import Path
    p = Path(p)
    return f"{p.parent.name}__{p.name}"
