"""
04_menu_tts.py  --  menu prompt audio (0-item.mp3) with Piper.

Prompts come from project.json:
  menu_prompts.root            -> tree/0-item.mp3          (pack cover)
  menu_prompts.category_chooser -> <menu>/0-item.mp3        (the chooser screen)
  categories[].prompt          -> <menu>/<cat>/0-item.mp3   (one per category)
When categories is empty the per-category prompts are skipped. Empty texts are
skipped too. Voice model + lead/tail silence from project.json ($Cfg.tts).

Run: uv run --python 3.12 --with piper-tts python scripts/04_menu_tts.py
Output: raw <sample_rate> mono MP3 (loudness handled by 04b_normalize).
"""
import subprocess, wave
from pathlib import Path
from _config import CONFIG, BUILD, FFMPEG, TREE, MENU, RAW_AUDIO, bak_name, require_tool

require_tool(FFMPEG, "ffmpeg")

TTS = CONFIG["tts"]
A = CONFIG["audio"]
SR = A["sample_rate"]
CH = A["channels"]
CL = "mono" if CH == 1 else "stereo"
LEAD = float(TTS.get("lead", 0.15))
TAIL = float(TTS.get("tail", 0.4))
WORK = BUILD / "work"

if TTS.get("engine", "piper") != "piper":
    raise SystemExit(f"moteur TTS non supporté : {TTS.get('engine')} (seul 'piper' est géré)")

_model = (TTS.get("model") or "").strip()
if not _model:
    raise SystemExit("tts.model manquant dans project.json (chemin vers la voix .onnx Piper)")
MODEL = Path(_model)
if not MODEL.is_absolute():
    MODEL = BUILD / _model
if not MODEL.exists():
    raise SystemExit(f"modèle TTS introuvable : {MODEL}")

from piper import PiperVoice

mp = CONFIG["menu_prompts"]
PROMPTS = []
if (mp.get("root") or "").strip():
    PROMPTS.append((TREE / "0-item.mp3", mp["root"].strip()))
if (mp.get("category_chooser") or "").strip():
    PROMPTS.append((MENU / "0-item.mp3", mp["category_chooser"].strip()))
for c in CONFIG["categories"]:
    if (c.get("prompt") or "").strip():
        PROMPTS.append((MENU / c["name"] / "0-item.mp3", c["prompt"].strip()))

voice = PiperVoice.load(str(MODEL))
for out, text in PROMPTS:
    wav = WORK / "menu_tts.wav"
    wav.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(wav), "wb") as w:
        voice.synthesize_wav(text, w)
    out.parent.mkdir(parents=True, exist_ok=True)
    # LEAD lead + TAIL tail silence, target rate/layout mp3
    fc = (f"[0:a]atrim=0:{LEAD}[l];[0:a]atrim=0:{TAIL}[t];"
          f"[1:a]aresample={SR},aformat=channel_layouts={CL}[v];[l][v][t]concat=n=3:v=0:a=1[o]")
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
                    "-f", "lavfi", "-i", f"anullsrc=r={SR}:cl={CL}", "-i", str(wav),
                    "-filter_complex", fc, "-map", "[o]",
                    "-ar", str(SR), "-ac", str(CH), "-c:a", "libmp3lame", "-b:a", "192k",
                    "-map_metadata", "-1", str(out)], check=True)
    # freshly re-synthesised at raw level -> drop the stale loudness backup so 04b re-captures
    (RAW_AUDIO / bak_name(out)).unlink(missing_ok=True)
    rel = out.relative_to(TREE) if TREE in out.parents else out.name
    print(f"  {rel}  <-  {text}")

print(f"\nOK - {len(PROMPTS)} prompts de menu")
