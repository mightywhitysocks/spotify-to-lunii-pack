"""
07_icons.py  --  replace the text screen images with simple line icons
(OpenMoji, negated to white-on-near-black), <w>x<h> from project.json.

Only runs when project.json sets  icons.mode == "emoji"  (default "off" -> no-op).
Category icons come from categories[].icon, story icons from story_icons
(keyed by the story key). OpenMoji set / URL / render background from $Cfg.icons.
first_menu_audio_only controls whether the chooser screen keeps an image.

Run: uv run --python 3.12 --with svglib --with reportlab --with lxml python scripts/07_icons.py
Then re-run 05_run_spg.ps1.
"""
import json, urllib.request
from pathlib import Path
from _config import CONFIG, BUILD, TREE, MENU, FFMPEG, require_tool
from _covers import place_on_canvas

ICONS = CONFIG["icons"]
CACHE = BUILD / "tools" / "openmoji"


def _render_bg():
    v = str(ICONS.get("render_bg", "0xF6F3EC")).lstrip("#")
    if v.lower().startswith("0x"):
        v = v[2:]
    return int(v, 16)


RENDER_BG = _render_bg()
CAT_ICON = {c["name"]: c["icon"] for c in CONFIG["categories"] if c.get("icon")}
STORY_ICON = {str(k): str(v) for k, v in CONFIG["story_icons"].items()}
URL = ICONS["url"].replace("{set}", ICONS["set"])


def get_png(code):
    """download + rasterise one OpenMoji svg -> 512px PNG."""
    png = CACHE / f"{code}.png"
    if png.exists():
        return png
    svg = CACHE / f"{code}.svg"
    if not svg.exists():
        try:
            urllib.request.urlretrieve(URL.replace("{code}", code), svg)
        except Exception as e:
            print(f"  !! {code}: {e}")
            return None
    from svglib.svglib import svg2rlg
    from reportlab.graphics import renderPM
    d = svg2rlg(str(svg))
    if d is None:
        return None
    s = 512 / max(d.width or 72, d.height or 72)
    d.scale(s, s); d.width *= s; d.height *= s
    renderPM.drawToFile(d, str(png), fmt="PNG", bg=RENDER_BG)
    return png


def compose(code, out: Path):
    png = get_png(code)
    return place_on_canvas(png, out, negate=True) if png else False


def main():
    if ICONS.get("mode") != "emoji":
        print("icônes désactivées (icons.mode=off)")
        return

    require_tool(FFMPEG, "ffmpeg")
    CACHE.mkdir(parents=True, exist_ok=True)
    stories = json.loads((BUILD / "stories_tree.json").read_text(encoding="utf-8"))
    ok = miss = 0

    if CONFIG.get("first_menu_audio_only"):
        p = MENU / "0-item.png"
        if p.exists():
            p.unlink()
            print(f"  audio seul (image supprimée): {p.relative_to(TREE)}")

    for cat, code in CAT_ICON.items():
        if compose(code, MENU / cat / "0-item.png"):
            ok += 1
        else:
            miss += 1
            print(f"  cat manquante: {cat}")

    for st in stories:
        key = st.get("key", "")
        code = STORY_ICON.get(key)
        if not code:
            print(f"  ?? pas d'icone pour '{key}' ({st['title']})")
            miss += 1
            continue
        if compose(code, Path(st["item_png"])):
            ok += 1
            print(f"  {code}  {st['title']}")
        else:
            miss += 1
            print(f"  ECHEC {code}  {st['title']}")

    print(f"\nOK {ok} images / {miss} manquantes (gardent le texte)")


if __name__ == "__main__":
    main()
