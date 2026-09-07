"""
08e_grayscale.py  --  keep the real Spotify/book cover, just convert to grayscale
320x240 for the Lunii screen (no tracing / thresholding).
Sample : uv run --python 3.12 python scripts/08e_grayscale.py "timote-a-la-ferme;timote-jardine"
All    : uv run --python 3.12 python scripts/08e_grayscale.py
Outputs: covers/gray/<slug>.png ; (08f_apply copies them onto the story screens)
Tune   : cover_tune.csv  ->  crop_top/crop_bottom (frac), gamma, contrast, style=icon to skip
"""
import csv, json, sys
from pathlib import Path
from _covers import BUILD, CV, IM, run, load_tune, gray_ops

RAW = CV / "raw"
GRAY = CV / "gray"
GRAY.mkdir(parents=True, exist_ok=True)
SAMPLE = [s.strip() for s in (sys.argv[1] if len(sys.argv) > 1 else "").split(";") if s.strip()]


def one(src: Path, out: Path, t: dict):
    ct = float(t.get("crop_top") or 0.30)          # cut the "TIMOTÉ" + title text
    cb = float(t.get("crop_bottom") or 0.16)       # cut the "lu par… / Lizzie" band
    # crop to the illustration -> shared grayscale treatment -> fill 320x240, no border
    rc, o = run(
        IM, str(src),
        "-gravity", "North", "-chop", f"0x{ct*100:.1f}%",
        "-gravity", "South", "-chop", f"0x{cb*100:.1f}%",
        *gray_ops(t),
        "-resize", "320x240^", "-gravity", "Center", "-extent", "320x240",
        "-strip", str(out))
    return rc == 0, o


def main():
    stories = json.loads((BUILD / "stories_tree.json").read_text(encoding="utf-8"))
    if SAMPLE:
        stories = [s for s in stories if s["base"] in SAMPLE]
    tune = load_tune()
    n = 0
    for st in stories:
        slug = st["base"]
        src = RAW / f"{slug}.jpg"
        if not src.exists():
            print(f"  no cover: {slug}"); continue
        if (tune.get(slug, {}).get("style") or "").lower() == "icon":
            print(f"  skip (icon): {slug}"); continue
        ok, o = one(src, GRAY / f"{slug}.png", tune.get(slug, {}))
        n += ok
        print(f"  {'OK' if ok else 'KO'}  {slug}" + ("" if ok else f"  {o[:100]}"))

    # self-contained review page
    import base64, html
    def img(p):
        return (f"<img src='data:image/png;base64,{base64.b64encode(p.read_bytes()).decode()}'>"
                if p.exists() else "<i>—</i>")
    doc = ["<!doctype html><meta charset=utf-8><title>Couvertures en gris</title>",
           "<style>body{font:13px system-ui;margin:20px;background:#ccc}"
           ".g{display:flex;flex-wrap:wrap;gap:12px}.c{width:322px;background:#fff;padding:6px}"
           "img{width:320px;height:240px;display:block}.l{font-size:12px;padding-top:4px}</style>",
           f"<h1>Couvertures en niveaux de gris — {n} "
           f"({'échantillon' if SAMPLE else 'complet'})</h1>",
           "<p>Réglage par couverture dans <code>cover_tune.csv</code> : "
           "<code>crop_top</code>/<code>crop_bottom</code> (0.06 = 6 %), "
           "<code>gamma</code> (1.1 = plus clair), <code>contrast</code> "
           "(<code>brightnessxcontrast</code>, ex <code>6x15</code>), "
           "<code>style=icon</code> pour garder le pictogramme.</p><div class=g>"]
    for st in stories:
        p = GRAY / f"{st['base']}.png"
        doc.append(f"<div class=c>{img(p)}<div class=l>{html.escape(st['title'])}</div></div>")
    doc.append("</div>")
    (BUILD / "covers_review.html").write_text("\n".join(doc), encoding="utf-8")
    print(f"\nOK — {n} couvertures. Voir {BUILD/'covers_review.html'}")


if __name__ == "__main__":
    main()
