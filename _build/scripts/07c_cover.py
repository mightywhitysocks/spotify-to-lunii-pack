"""
07c_cover.py  --  the pack cover image  ->  tree/0-item.png  (<w>x<h>).

project.json  pack_cover.mode:
  none      -> no-op (SPG will use its own cover, or none)
  image     -> take pack_cover.src as-is: fit on the canvas + shared grayscale
  floodfill -> flood-fill pack_cover.bg transparent from the 8 edge/mid points
               (fuzz pack_cover.fuzz), trim, then place the figure on black +
               shared grayscale (the Timoté "cut-out of the Spotify photo" case)
Tune: cover_tune.csv row  slug=_cover  (contrast / clahe / autolevel / gamma)
Run: uv run --python 3.12 python scripts/07c_cover.py   then  05_run_spg.ps1
"""
from pathlib import Path
from _config import CONFIG, BUILD, require_tool
from _covers import IM, TREE, CANVAS, W, H, run, load_tune, gray_ops

PC = CONFIG["pack_cover"]
OUT = TREE / "0-item.png"


def _src():
    s = (PC.get("src") or "").strip()
    if not s:
        return None
    p = Path(s)
    return p if p.is_absolute() else BUILD / s


def main():
    mode = PC.get("mode", "none")
    if mode == "none":
        print("couverture du pack désactivée (pack_cover.mode=none)")
        return

    require_tool(IM, "imagemagick")
    src = _src()
    if not src or not src.exists():
        raise SystemExit(f"pack_cover.src introuvable : {src}")
    t = load_tune().get("_cover", {})

    if mode == "image":
        rc, o = run(
            IM, str(src),
            "-resize", f"{W}x{H}^", "-gravity", "center", "-extent", f"{W}x{H}",
            *gray_ops(t),
            "-background", CANVAS, "-flatten", "-strip", str(OUT))
    elif mode == "floodfill":
        pts = ["+0+0", "+639+0", "+0+639", "+639+639", "+320+0", "+0+320", "+639+320", "+320+639"]
        ff = [x for p in pts for x in ("-floodfill", p, PC["bg"])]
        rc, o = run(
            IM, str(src), "-alpha", "set", "-fuzz", PC["fuzz"], "-fill", "none", *ff,
            "-trim", "+repage",
            "-resize", f"{W}x{H-4}", "-background", CANVAS, "-gravity", "center",
            "-extent", f"{W}x{H}", "-flatten",
            *gray_ops(t, autolevel_default="0"),   # default OFF: big black area, avoid blow-out
            "-strip", str(OUT))
    else:
        raise SystemExit(f"pack_cover.mode inconnu : {mode}")

    print(("OK  " if rc == 0 else "KO  ") + str(OUT) + ("" if rc == 0 else f"\n{o[:300]}"))


if __name__ == "__main__":
    main()
