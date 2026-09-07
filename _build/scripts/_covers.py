"""shared helpers for the cover / icon image scripts."""
import csv, subprocess
from pathlib import Path
from _config import BUILD, FFMPEG, IM, CANVAS, TREE

CV = BUILD / "covers"
TUNE = BUILD / "cover_tune.csv"


def run(*a):
    r = subprocess.run([str(x) for x in a], capture_output=True, text=True)
    return r.returncode, (r.stdout + r.stderr)


def load_tune():
    d = {}
    if TUNE.exists():
        for r in csv.DictReader(TUNE.open(encoding="utf-8-sig")):
            d[r["slug"]] = r
    return d


def gray_ops(t: dict, autolevel_default="1"):
    """ImageMagick args for the shared 'Lunii screen' grayscale treatment
    (gentle local + global contrast, light edge sharpen, no crushing).
    Per-image tuning from a cover_tune.csv row `t`. Used by 08e and 07c."""
    autolvl = (t.get("autolevel") or autolevel_default) != "0"
    return [
        "-colorspace", "Gray",
        "-clahe", str(t.get("clahe") or "16x16%+128+2"),
        "-sigmoidal-contrast", str(t.get("contrast") or "4x50%"),
        "-unsharp", "0x0.8+0.6+0",
        *(["-auto-level"] if autolvl else []),
        "-gamma", str(t.get("gamma") or "1.0"),
    ]


def place_on_canvas(src, out: Path, negate: bool):
    """scale `src` to fit 232px and centre it on the 320x240 near-black CANVAS
    (optionally negating first). Shared by 07_icons and any single-subject image."""
    out.parent.mkdir(parents=True, exist_ok=True)
    vf = (("negate," if negate else "")
          + "scale=232:232:force_original_aspect_ratio=decrease:flags=lanczos,"
          + f"pad=320:240:(ow-iw)/2:(oh-ih)/2:{CANVAS}")
    rc, _ = run(FFMPEG, "-hide_banner", "-loglevel", "error", "-y", "-i", src,
                "-vf", vf, "-frames:v", "1", out)
    return rc == 0 and Path(out).exists()
