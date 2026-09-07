"""
07_icons.py  --  replace the text screen images with simple black-on-white
line icons (OpenMoji 'black' set, Noun-Project-ish style), 320x240.

Run: uv run --python 3.12 --with svglib --with reportlab --with lxml python scripts/07_icons.py
Then re-run 05_run_spg.ps1.
Fallback: if an emoji SVG is missing, that screen keeps a text image.
"""
import json, urllib.request
from pathlib import Path
from _config import BUILD, TREE
from _covers import place_on_canvas

MENU = TREE / "Histoires de Timote"
CACHE = BUILD / "tools" / "openmoji"
CACHE.mkdir(parents=True, exist_ok=True)
RENDER_BG = 0xF6F3EC      # reportlab render background (before negate -> near-black CANVAS)

CAT_ICON = {                                # concrete objects a 2-4 y.o. recognises
    "1 Quotidien et autonomie": "1F3E0",   # house
    "2 Emotions et grandir":     "1F60A",   # smiling face
    "3 Ecole":                   "1F3EB",   # school building (was 1F392 backpack)
    "4 Sorties et culture":      "1F3AA",   # circus tent
    "5 Voyages":                 "1F697",   # car
    "6 Sport et plein air":      "26BD",    # ball
    "7 Fetes":                   "1F382",   # birthday cake
    "8 Corps et sante":          "1FA79",   # adhesive bandage
    "9 Nature et animaux":       "1F98B",   # butterfly
}
STORY_ICON = {
    "aime tout faire tout seul": "1F4AA",   # biceps
    "decouvre les chiffres":     "1F522",   # 1234
    "decouvre les lettres":      "1F524",   # abc
    "et sa tetine":              "1F476",   # baby
    "et son doudou":             "1F9F8",   # teddy bear
    "fait un gateau":            "1F9C1",   # cupcake
    "jardine":                   "1F331",   # seedling
    "devient grand frere":       "1F37C",   # baby bottle
    "dort chez un copain":       "1F6CC",   # person in bed
    "est amoureux":              "1F498",   # heart with arrow
    "et la petite souris":       "1F9B7",   # tooth
    "et les ecrans":             "1F4F1",   # mobile phone
    "et ses emotions":           "1F60A",   # smiling face
    "fait des betises":          "1F648",   # see-no-evil monkey
    "aime la musique":           "1F3B5",   # musical note
    "apprend l anglais":         "1F4D6",   # open book
    "entre a l ecole":           "1F3EB",   # school
    "va a la cantine":           "1F374",   # fork and knife
    "va au centre de loisirs":   "1F3A8",   # artist palette
    "a l aquarium":              "1F420",   # tropical fish
    "va a la bibliotheque":      "1F4DA",   # books
    "va au cirque":              "1F3AA",   # circus tent
    "va au spectacle":           "1F3AC",   # clapper board
    "visite le louvre":          "1F5BC",   # framed picture
    "visite le musee d orsay":   "1F3DB",   # classical building
    "visite paris":              "1F5FC",   # tower
    "visite un chateau fort":    "1F3F0",   # castle
    "prend le train":            "1F682",   # locomotive
    "visite la bretagne":        "26F5",    # sailboat
    "fait de la trottinette":    "1F6F4",   # kick scooter
    "fait du ski":               "1F3BF",   # skis
    "fait du velo":              "1F6B2",   # bicycle
    "joue au foot":              "26BD",    # soccer ball
    "se promene en foret":       "1F332",   # evergreen tree
    "et le noel magique":        "1F384",   # christmas tree
    "fete la saint nicolas":     "1F381",   # wrapped gift
    "fete son anniversaire":     "1F388",   # balloon
    "est malade":                "1F912",   # face with thermometer
    "et ses lunettes":           "1F453",   # glasses
    "va chez le docteur":        "1F3E5",   # hospital
    "a la ferme":                "1F404",   # cow
    "aime la planete":           "1F30D",   # earth globe
    "veut un animal":            "1F436",   # dog face
    "chez les pompiers":         "1F692",   # fire engine
    "et le chantier":            "1F6A7",   # construction sign
}
URL = "https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/black/svg/{}.svg"


def get_png(code):
    """download + rasterise one OpenMoji black svg -> 512px transparent PNG."""
    png = CACHE / f"{code}.png"
    if png.exists():
        return png
    svg = CACHE / f"{code}.svg"
    if not svg.exists():
        try:
            urllib.request.urlretrieve(URL.format(code), svg)
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
    # black OpenMoji -> negate -> white icon centred on the near-black Lunii canvas
    png = get_png(code)
    return place_on_canvas(png, out, negate=True) if png else False


def norm_key(title):
    import unicodedata
    s = unicodedata.normalize("NFD", title.lower())
    s = "".join(c for c in s if unicodedata.category(c) != "Mn")
    s = "".join(c if c.isalnum() else " " for c in s)
    return " ".join(s.replace("timote", "").split())


def main():
    stories = json.loads((BUILD / "stories_tree.json").read_text(encoding="utf-8"))
    ok = miss = 0

    # "choisis un thème" screen: AUDIO ONLY, no image (user request).
    # pack cover image is built separately by 07c_cover.py (isolated Timoté) -> keep it.
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
        key = norm_key(st["title"])
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
