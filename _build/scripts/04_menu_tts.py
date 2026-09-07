"""
04_menu_tts.py  --  menu prompt audio (0-item.mp3) with Piper fr_FR-siwis-medium.
  pack cover, first menu, 9 category prompts.
Run: uv run --python 3.12 --with piper-tts python scripts/04_menu_tts.py
Output: raw 44.1kHz mono MP3 (loudness handled by 04b_normalize).
"""
import subprocess, wave
from piper import PiperVoice
from _config import BUILD, FFMPEG, TREE, RAW_AUDIO, bak_name

MODEL = BUILD / "tools" / "piper" / "fr_FR-siwis-medium.onnx"
MENU = TREE / "Histoires de Timote"
WORK = BUILD / "work"

PROMPTS = [
    (TREE / "0-item.mp3", "Choisis une histoire de Timoté."),
    (MENU / "0-item.mp3", "Choisis un thème."),
    (MENU / "1 Quotidien et autonomie" / "0-item.mp3", "Le quotidien."),
    (MENU / "2 Emotions et grandir"    / "0-item.mp3", "Les émotions."),
    (MENU / "3 Ecole"                  / "0-item.mp3", "L'école."),
    (MENU / "4 Sorties et culture"     / "0-item.mp3", "Les sorties et la culture."),
    (MENU / "5 Voyages"                / "0-item.mp3", "Les voyages."),
    (MENU / "6 Sport et plein air"     / "0-item.mp3", "Le sport et le plein air."),
    (MENU / "7 Fetes"                  / "0-item.mp3", "Les fêtes."),
    (MENU / "8 Corps et sante"         / "0-item.mp3", "Le corps et la santé."),
    (MENU / "9 Nature et animaux"      / "0-item.mp3", "La nature et les animaux."),
]

voice = PiperVoice.load(str(MODEL))
for out, text in PROMPTS:
    wav = WORK / "menu_tts.wav"
    with wave.open(str(wav), "wb") as w:
        voice.synthesize_wav(text, w)
    out.parent.mkdir(parents=True, exist_ok=True)
    # 0.15s lead + 0.4s tail silence, 44.1k mono mp3
    fc = ("[0:a]atrim=0:0.15[l];[0:a]atrim=0:0.4[t];"
          "[1:a]aresample=44100,aformat=channel_layouts=mono[v];[l][v][t]concat=n=3:v=0:a=1[o]")
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
                    "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono", "-i", str(wav),
                    "-filter_complex", fc, "-map", "[o]",
                    "-ar", "44100", "-ac", "1", "-c:a", "libmp3lame", "-b:a", "192k",
                    "-map_metadata", "-1", str(out)], check=True)
    # freshly re-synthesised at raw level -> drop the stale loudness backup so 04b re-captures
    (RAW_AUDIO / bak_name(out)).unlink(missing_ok=True)
    print(f"  {out.relative_to(TREE)}  <-  {text}")

print(f"\nOK - {len(PROMPTS)} prompts de menu")
