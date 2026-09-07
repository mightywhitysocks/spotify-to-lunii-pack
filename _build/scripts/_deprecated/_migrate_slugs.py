"""one-shot: migrate cover assets + CSVs from the old category-coupled base
('03 Timote va chez le docteur') to the stable slug ('timote-va-chez-le-docteur').
Run BEFORE 01/02. Idempotent-ish: skips a rename whose source is already gone.
"""
import csv, json
from _config import BUILD

CV = BUILD / "covers"
tree = json.loads((BUILD / "stories_tree.json").read_text(encoding="utf-8"))
old2slug = {s["base"]: "timote-" + s["key"].replace(" ", "-") for s in tree}
print(f"{len(old2slug)} histoires")

for sub, ext in (("raw", ".jpg"), ("gray", ".png")):
    d = CV / sub
    if not d.exists():
        continue
    for old, slug in old2slug.items():
        src, dst = d / f"{old}{ext}", d / f"{slug}{ext}"
        if src.exists() and not dst.exists():
            src.rename(dst)
            print(f"  {sub}: {old}{ext} -> {slug}{ext}")

# covers_urls.csv : rewrite the slug column
p = BUILD / "covers_urls.csv"
if p.exists():
    rows = list(csv.DictReader(p.open(encoding="utf-8-sig")))
    for r in rows:
        r["slug"] = old2slug.get(r["slug"], r["slug"])
    with p.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, list(rows[0].keys()))
        w.writeheader(); w.writerows(rows)
    print(f"  covers_urls.csv : {len(rows)} lignes reclees")

# title_windows.csv : the hand-tuned windows were lost to the old wipe bug; start
# a fresh file that carries ONLY the 4 windows we just re-identified by whisper.
MANUAL = {
    "timote-va-au-centre-de-loisirs": (11.4, 15.1),
    "timote-va-au-spectacle":         (12.7, 15.0),
    "timote-fait-du-ski":             (13.6, 16.1),
    "timote-est-malade":              (11.0, 13.7),
}
tw = BUILD / "title_windows.csv"
with tw.open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, ["base", "start", "end", "dur", "method", "flag", "title"])
    w.writeheader()
    for slug, (s, e) in MANUAL.items():
        w.writerow(dict(base=slug, start=s, end=e, dur="", method="", flag="", title=""))
print(f"  title_windows.csv : {len(MANUAL)} fenetres manuelles")

# cover_tune.csv : the 2 covers reported as "cramees" -> gentler, no -auto-level
tune = BUILD / "cover_tune.csv"
COLS = ["slug", "crop_top", "crop_bottom", "gamma", "contrast", "clahe", "autolevel", "style"]
CRAMEES = ("timote-va-chez-le-docteur", "timote-aime-la-planete")
existing = {}
if tune.exists():
    for r in csv.DictReader(tune.open(encoding="utf-8-sig")):
        existing[r["slug"]] = r
for slug in CRAMEES:
    existing[slug] = dict(slug=slug, crop_top="", crop_bottom="", gamma="0.92",
                          contrast="3x42%", clahe="8x8%+128+1", autolevel="0", style="")
with tune.open("w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, COLS)
    w.writeheader()
    for r in existing.values():
        w.writerow({k: r.get(k, "") for k in COLS})
print(f"  cover_tune.csv : {len(existing)} lignes ({', '.join(CRAMEES)} adoucies)")
