"""Regenerate a self-contained titles_review.html with the audio embedded
(base64 data URIs) so it plays anywhere, no local file access needed."""
import base64, csv, json, html
from pathlib import Path

BUILD = Path(__file__).resolve().parent.parent
tr = {s["base"]: s for s in json.loads((BUILD / "stories_tree.json").read_text(encoding="utf-8"))}
rows = list(csv.DictReader((BUILD / "title_windows.csv").open(encoding="utf-8-sig")))

parts = ["<!doctype html><meta charset=utf-8><title>Annonces de titre - Timoté</title>",
         "<style>body{font:14px/1.4 system-ui,sans-serif;margin:24px;max-width:820px;color:#222}"
         "h1{font-size:20px}table{border-collapse:collapse;width:100%}"
         "td,th{padding:7px 10px;text-align:left;border-bottom:1px solid #e3e3e3;vertical-align:middle}"
         "tr:hover{background:#f7f7f7}.flag{color:#c00;font-weight:600}"
         "audio{height:34px}.cat{color:#888;font-size:12px}</style>",
         f"<h1>Annonces de titre — {len(rows)} histoires "
         f"({sum(1 for r in rows if r['flag'])} à réécouter)</h1>",
         "<p>Chaque ligne = ce qui est joué quand l'enfant s'arrête sur l'histoire à la molette. "
         "Pour corriger une découpe : renseigne <b>start,end</b> (secondes dans le chapitre 1) "
         "sur sa ligne de <code>title_windows.csv</code>, puis relance "
         "<code>03_titles.py</code> → <code>04b</code> → <code>06</code>.</p>",
         "<table><tr><th>#</th><th>Histoire</th><th>Écoute</th><th>Durée</th><th>Méthode</th></tr>"]

for r in rows:
    st = tr[r["base"]]
    mp3 = Path(st["item_mp3"])
    if mp3.exists():
        b64 = base64.b64encode(mp3.read_bytes()).decode()
        audio = f"<audio controls preload=metadata src='data:audio/mpeg;base64,{b64}'></audio>"
    else:
        audio = "<i>absent</i>"
    fl = f" <span class=flag>{r['flag']}</span>" if r["flag"] else ""
    parts.append(
        f"<tr><td>{html.escape(r['base'].split()[0])}</td>"
        f"<td>{html.escape(r['title'])}<div class=cat>{html.escape(st['category'])}</div></td>"
        f"<td>{audio}</td><td>{r['dur']}s</td><td>{r['method']}{fl}</td></tr>")

parts.append("</table>")
out = BUILD / "titles_review.html"
out.write_text("\n".join(parts), encoding="utf-8")
size = out.stat().st_size / 1024
print(f"OK -> {out}  ({size:.0f} KB, audio embarqué)")
