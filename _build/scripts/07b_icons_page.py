"""Self-contained gallery of every screen image, grouped by menu."""
import base64, json, html
from pathlib import Path
from _config import CONFIG, BUILD, TREE, MENU, resolve_tree_path

TITLE = CONFIG["title"]
stories = json.loads((BUILD / "stories_tree.json").read_text(encoding="utf-8"))


def img(p: Path):
    if not p.exists():
        return "<i>—</i>"
    b = base64.b64encode(p.read_bytes()).decode()
    return f"<img src='data:image/png;base64,{b}'>"


cells = [("Couverture", TREE / "0-item.png"),
         ("Menu", MENU / "0-item.png")]
parts = [f"<!doctype html><meta charset=utf-8><title>Images du pack {html.escape(TITLE)}</title>",
         "<style>body{font:14px/1.4 system-ui;margin:24px;max-width:1000px;background:#fafafa}"
         "h2{margin:26px 0 8px;font-size:16px;border-bottom:2px solid #ddd;padding-bottom:4px}"
         ".g{display:flex;flex-wrap:wrap;gap:14px}"
         ".c{width:172px;text-align:center}img{width:170px;height:128px;border:1px solid #ccc;"
         "border-radius:4px;background:#fff}.l{font-size:12px;margin-top:4px;color:#444}</style>",
         f"<h1>Images du pack « {html.escape(TITLE)} »</h1>",
         "<h2>Écrans généraux</h2><div class=g>"]
for lab, p in cells:
    parts.append(f"<div class=c>{img(p)}<div class=l>{html.escape(lab)}</div></div>")
parts.append("</div>")

by_cat = {}
for s in stories:
    by_cat.setdefault(s.get("category") or "", []).append(s)

if list(by_cat) == [""]:                       # flat menu, no categories
    parts.append("<h2>Histoires</h2><div class=g>")
    for s in by_cat[""]:
        parts.append(f"<div class=c>{img(resolve_tree_path(s['item_png']))}"
                     f"<div class=l>{html.escape(s['title'])}</div></div>")
    parts.append("</div>")
else:
    for cat in sorted(by_cat):
        parts.append(f"<h2>{html.escape(cat)}</h2><div class=g>")
        parts.append(f"<div class=c>{img(MENU / cat / '0-item.png')}"
                     f"<div class=l><b>[thème]</b></div></div>")
        for s in by_cat[cat]:
            parts.append(f"<div class=c>{img(resolve_tree_path(s['item_png']))}"
                         f"<div class=l>{html.escape(s['title'])}</div></div>")
        parts.append("</div>")

out = BUILD / "icons_review.html"
out.write_text("\n".join(parts), encoding="utf-8")
print(f"OK -> {out}  ({out.stat().st_size // 1024} KB)")
