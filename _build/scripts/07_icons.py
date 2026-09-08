"""
07_icons.py  --  replace the text screen images with simple line icons
(negated to white-on-near-black), <w>x<h> from project.json.

Only runs when project.json sets  icons.mode == "emoji"  (default "off" -> no-op).
Category icons come from categories[].icon, story icons from story_icons
(keyed by the story key). Each identifier is either a bare OpenMoji hex code
("1F3E0", the legacy/default source) or "<prefix>:<name>" ("material:museum")
for an extra icon library declared in icons.sources (a {prefix: url template}
map, empty by default -- see project.schema.md). OpenMoji set / URL / render
background from $Cfg.icons. first_menu_audio_only controls whether the
chooser screen keeps an image.

Run: uv run --python 3.12 --with svglib --with reportlab --with lxml python scripts/07_icons.py
Then re-run 05_run_spg.ps1.
"""
import json, urllib.request
from pathlib import Path
from _config import CONFIG, BUILD, TREE, MENU, FFMPEG, require_tool, resolve_tree_path
from _covers import place_on_canvas

ICONS = CONFIG["icons"]
# OpenMoji cache, namespaced by set ("black", "color", ...) so switching
# icons.set in project.json can never reuse PNGs rendered from the old set.
CACHE = BUILD / "tools" / "openmoji" / str(ICONS["set"])
ICONS_ROOT = BUILD / "tools" / "icons"         # extra sources, namespaced by prefix
SOURCES = ICONS.get("sources", {})


def _render_bg():
    v = str(ICONS.get("render_bg", "0xF6F3EC")).lstrip("#")
    if v.lower().startswith("0x"):
        v = v[2:]
    return int(v, 16)


RENDER_BG = _render_bg()
CAT_ICON = {c["name"]: c["icon"] for c in CONFIG["categories"] if c.get("icon")}
STORY_ICON = {str(k): str(v) for k, v in CONFIG["story_icons"].items()}
URL = ICONS["url"].replace("{set}", ICONS["set"])


def _parse_ident(ident: str):
    """'1F3E0' -> ('openmoji', '1F3E0') ; 'material:museum' -> ('material', 'museum')."""
    if ":" in ident:
        prefix, name = ident.split(":", 1)
        return prefix, name
    return "openmoji", ident


def _cache_dir(prefix: str) -> Path:
    d = CACHE if prefix == "openmoji" else ICONS_ROOT / prefix
    d.mkdir(parents=True, exist_ok=True)
    return d


def _icon_url(prefix: str, name: str) -> str:
    if prefix == "openmoji":
        return URL.replace("{code}", name)
    tmpl = SOURCES.get(prefix)
    if not tmpl:
        raise ValueError(f"source d'icône inconnue: '{prefix}' (à déclarer dans icons.sources)")
    return tmpl.replace("{code}", name)


def get_png(ident):
    """download + rasterise one icon ('1F3E0' or 'material:museum') -> 512px PNG."""
    prefix, name = _parse_ident(ident)
    cache = _cache_dir(prefix)
    png = cache / f"{name}.png"
    if png.exists():
        return png
    svg = cache / f"{name}.svg"
    if not svg.exists():
        try:
            urllib.request.urlretrieve(_icon_url(prefix, name), svg)
            if prefix != "openmoji":
                # Lucide/Tabler use stroke="currentColor"; svglib has no CSS
                # cascade to resolve it, so pin it to black (OpenMoji already
                # ships hard-coded colours -- no-op for it).
                svg.write_text(
                    svg.read_text(encoding="utf-8").replace("currentColor", "#000000"),
                    encoding="utf-8",
                )
        except Exception as e:
            print(f"  !! {ident}: {e}")
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


def compose(ident, out: Path):
    png = get_png(ident)
    return place_on_canvas(png, out, negate=True) if png else False


def main():
    if ICONS.get("mode") != "emoji":
        print("icônes désactivées (icons.mode=off)")
        return

    require_tool(FFMPEG, "ffmpeg")
    CACHE.mkdir(parents=True, exist_ok=True)
    stories = json.loads((BUILD / "stories_tree.json").read_text(encoding="utf-8"))
    ok = miss = 0
    missing = []          # human labels of every screen left without an icon

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
            missing.append(f"catégorie: {cat}")
            print(f"  cat manquante: {cat}")

    for st in stories:
        key = st.get("key", "")
        code = STORY_ICON.get(key)
        if not code:
            print(f"  ?? pas d'icone pour '{key}' ({st['title']})")
            miss += 1
            missing.append(f"{st['title']} (pas de code dans story_icons)")
            continue
        if compose(code, resolve_tree_path(st["item_png"])):
            ok += 1
            print(f"  {code}  {st['title']}")
        else:
            miss += 1
            missing.append(f"{st['title']} ({code})")
            print(f"  ECHEC {code}  {st['title']}")

    # Report consumed by 05_run_spg.ps1: it only lets SPG skip its own text-image
    # generation when this says every screen got an icon. Otherwise SPG must fill
    # the gaps, or a missing/failed icon ships with no image at all on a cold
    # start (02_merge.ps1 never creates an item.png -- it only reconciles one).
    report = BUILD / "work" / "icons_report.json"
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps(
        {"mode": "emoji", "ok": ok, "miss": miss,
         "missing": missing, "complete": not missing},
        ensure_ascii=False, indent=2), encoding="utf-8")

    if missing:
        print(f"\nOK {ok} images / {miss} manquantes -> SPG rendra un écran "
              f"texte de secours (05_run_spg.ps1 ne passe --skip-image-item-gen "
              f"que si 0 manquante)")
    else:
        print(f"\nOK {ok} images / 0 manquante")


if __name__ == "__main__":
    main()
