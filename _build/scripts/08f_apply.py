r"""
08f_apply.py  --  copy the grayscale covers onto the 45 story screens.
  covers/gray/<slug>.png  ->  tree\...\<base>.item.png   (overwrites the pictogram)
  cover_tune.csv  style=icon  OR  no grayscale file  ->  keep the OpenMoji pictogram
Pack cover / menu / 9 themes are untouched.
Run: py scripts/08f_apply.py    then    scripts/05_run_spg.ps1
"""
import json, shutil
from pathlib import Path
from _covers import BUILD, CV, load_tune

GRAY = CV / "gray"


def main():
    stories = json.loads((BUILD / "stories_tree.json").read_text(encoding="utf-8"))
    tune = load_tune()
    applied = kept = 0
    for st in stories:
        slug = st["base"]
        dst = Path(st["item_png"])
        if (tune.get(slug, {}).get("style") or "").lower() == "icon":
            kept += 1
            print(f"  icon  {slug}")
            continue
        src = GRAY / f"{slug}.png"
        if src.exists():
            shutil.copyfile(src, dst)
            applied += 1
            print(f"  gray  {slug}")
        else:
            kept += 1
            print(f"  icon  {slug}  (pas de gris)")
    print(f"\nOK — {applied} couvertures en gris, {kept} pictogrammes conservés."
          f"\n> relancer  scripts\\05_run_spg.ps1")


if __name__ == "__main__":
    main()
