"""
07c_cover.py  --  pack cover image: Timoté cut out of the Spotify artist
profile picture, dropped on black, same grayscale treatment as the story covers.
  covers/raw/_artist_timote.jpg  ->  tree/0-item.png  (320x240)
Run: uv run --python 3.12 python scripts/07c_cover.py   then  05_run_spg.ps1
Tune: cover_tune.csv row  slug=_cover  (contrast / clahe / autolevel / gamma)
"""
from _covers import CV, IM, TREE, CANVAS, run, load_tune, gray_ops

SRC = CV / "raw" / "_artist_timote.jpg"
OUT = TREE / "0-item.png"
BG = "srgb(52,60,132)"          # the flat indigo profile background


def main():
    if not SRC.exists():
        raise SystemExit(f"manque {SRC}")
    t = load_tune().get("_cover", {})
    # flood-fill the flat background transparent from 8 edge points, then place
    # the isolated figure on black and apply the shared grayscale treatment.
    pts = ["+0+0", "+639+0", "+0+639", "+639+639", "+320+0", "+0+320", "+639+320", "+320+639"]
    ff = [x for p in pts for x in ("-floodfill", p, BG)]
    rc, o = run(
        IM, str(SRC), "-alpha", "set", "-fuzz", "22%", "-fill", "none", *ff,
        "-trim", "+repage",
        "-resize", "320x236", "-background", CANVAS, "-gravity", "center",
        "-extent", "320x240", "-flatten",
        *gray_ops(t, autolevel_default="0"),   # default OFF: big black area, avoid blow-out
        "-strip", str(OUT))
    print(("OK  " if rc == 0 else "KO  ") + str(OUT) + ("" if rc == 0 else f"\n{o[:300]}"))


if __name__ == "__main__":
    main()
