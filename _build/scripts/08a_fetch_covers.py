r"""
08a_fetch_covers.py  --  fetch each story's Spotify album cover (the book cover).

Needs _build\.spotify  with  CLIENT_ID=...  /  CLIENT_SECRET=...
(app from developer.spotify.com, client-credentials flow, public catalogue only).

Run: uv run --python 3.12 --with requests python scripts/08a_fetch_covers.py
Outputs: covers/raw/<slug>.jpg , covers_urls.csv , covers_raw_index.html
Manual override: put a url on a slug's row of covers_urls.csv -> it wins.
"""
import base64, csv, json, re, time, unicodedata, html
from pathlib import Path
import requests

BUILD = Path(__file__).resolve().parent.parent
RAW = BUILD / "covers" / "raw"
RAW.mkdir(parents=True, exist_ok=True)
CSV = BUILD / "covers_urls.csv"
IDX = BUILD / "covers_raw_index.html"
CONF = BUILD / ".spotify"

BAD_ALBUM = re.compile(r"\b(5 histoires|aventures de timot|int[ée]grale|coffret|compilation|"
                       r"une ann[ée]e avec|le quotidien de timot|best of|volume)\b", re.I)
GOOD_ARTIST = re.compile(r"lizzie|gr[üu]nd|timot|massonaud", re.I)


def norm(s):
    s = unicodedata.normalize("NFD", s.lower())
    return " ".join("".join(c for c in s if unicodedata.category(c) != "Mn")
                    .replace("'", " ").split())


def load_conf():
    d = {}
    for line in CONF.read_text(encoding="utf-8").splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            d[k.strip()] = v.strip().strip('"')
    return d["CLIENT_ID"], d["CLIENT_SECRET"]


def token(cid, sec):
    b = base64.b64encode(f"{cid}:{sec}".encode()).decode()
    r = requests.post("https://accounts.spotify.com/api/token",
                      headers={"Authorization": f"Basic {b}"},
                      data={"grant_type": "client_credentials"}, timeout=20)
    r.raise_for_status()
    return r.json()["access_token"]


def _get(url, h, params, tries=4):
    for i in range(tries):
        r = requests.get(url, headers=h, params=params, timeout=25)
        if r.status_code == 200:
            return r
        wait = int(r.headers.get("Retry-After", 0)) or 6
        print(f"    HTTP {r.status_code} ({r.text[:80]}), wait {wait}s")
        time.sleep(wait)
    return r


def search_album(tok, title):
    """return (album_name, cover_url, score, artists) best match, or (None,None,0,'')."""
    h = {"Authorization": f"Bearer {tok}"}
    for typ in ("album",):
        r = _get("https://api.spotify.com/v1/search", h,
                 {"q": title, "type": typ, "limit": 10})
        if r.status_code != 200:
            continue
        key = typ + "s"
        items = r.json().get(key, {}).get("items", []) or []
        nt = norm(title)
        best = (None, None, 0.0, "")
        for it in items:
            if it is None:
                continue
            name = it.get("name", "")
            nn = norm(name)
            arts = " ".join(a.get("name", "") for a in it.get("artists", [])) \
                if it.get("artists") else it.get("authors", [{}])[0].get("name", "")
            imgs = it.get("images", [])
            if not imgs:
                continue
            score = 0.0
            if nn == nt:
                score = 1.0
            elif nt in nn or nn in nt:
                score = 0.8
            else:
                common = len(set(nt.split()) & set(nn.split()))
                score = common / max(1, len(nt.split())) * 0.6
            if BAD_ALBUM.search(name):
                score -= 0.5
            if GOOD_ARTIST.search(arts) or GOOD_ARTIST.search(name):
                score += 0.15
            if it.get("total_tracks", 99) <= 3:
                score += 0.1
            if score > best[2]:
                best = (name, imgs[0]["url"], score, arts)
        if best[0] and best[2] >= 0.45:
            return best
    return (None, None, 0.0, "")


def main():
    stories = json.loads((BUILD / "stories_tree.json").read_text(encoding="utf-8"))
    manual = {}
    if CSV.exists():
        for r in csv.DictReader(CSV.open(encoding="utf-8-sig")):
            if r.get("url", "").startswith("http"):
                manual[r["slug"]] = r["url"]

    cid, sec = load_conf()
    tok = token(cid, sec)
    rows = []
    for st in stories:
        slug = st["base"]
        title = st["title"]
        raw = RAW / f"{slug}.jpg"
        if slug in manual:
            url, album, score = manual[slug], "(manuel)", 1.0
        else:
            album, url, score, arts = search_album(tok, title)
            time.sleep(1.4)
        if url and not raw.exists():
            try:
                raw.write_bytes(requests.get(url, timeout=30).content)
            except Exception as e:
                print(f"  DL fail {slug}: {e}")
        time.sleep(0.4)
        got = raw.exists()
        rows.append(dict(slug=slug, titre=title, album_trouve=album or "",
                         url=url or "", score=round(score, 2), ok=int(got)))
        print(f"  {'OK ' if got else '?? '} {score:4.2f}  {slug:34}  <- {album}")

    with CSV.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, ["slug", "titre", "album_trouve", "url", "score", "ok"])
        w.writeheader(); w.writerows(rows)

    doc = ["<!doctype html><meta charset=utf-8><title>Pochettes Timoté (brut)</title>",
           "<style>body{font:13px system-ui;margin:20px;background:#eee}"
           ".g{display:flex;flex-wrap:wrap;gap:12px}.c{width:190px;background:#fff;padding:6px;"
           "border-radius:5px}.c img{width:178px;height:178px;object-fit:contain}"
           ".l{font-size:11px}.bad{color:#c00}</style>",
           f"<h1>Pochettes récupérées — {sum(r['ok'] for r in rows)}/{len(rows)}</h1>",
           "<p>Vérifier que chaque pochette = le bon livre. Sinon : mettre la bonne URL image "
           "dans <code>covers_urls.csv</code> (colonne url) et relancer.</p><div class=g>"]
    for r in rows:
        p = RAW / f"{r['slug']}.jpg"
        im = (f"<img src='file:///{p.as_posix()}'>" if p.exists()
              else "<div style='height:178px;color:#c00'>— absent —</div>")
        cls = "bad" if (not r["ok"] or r["score"] < 0.6) else ""
        doc.append(f"<div class=c>{im}<div class='l {cls}'>{html.escape(r['titre'])}<br>"
                   f"<small>{html.escape(r['album_trouve'])} · {r['score']}</small></div></div>")
    doc.append("</div>")
    IDX.write_text("\n".join(doc), encoding="utf-8")
    print(f"\nOK — {sum(r['ok'] for r in rows)}/{len(rows)} pochettes. Voir {IDX}")


if __name__ == "__main__":
    main()
