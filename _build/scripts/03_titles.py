"""
03_titles.py  --  extract the spoken title from each story's chapter 1.

Intro pattern (verified, soft music bed underneath the whole intro):
  "Les editions Grund et Lizzie [en partenariat ...] presente(nt)
   <Timote TITLE> ( << ... >> | , une histoire d' | de ) <authors>, lu par <narrator>."

Pass 1 : transcribe first 32 s -> end-of-'presente(nt)' .. start of 'une/de/>>' -> window.
Pass 2 : Silero VAD on that window -> first..last speech region (ignores music bed) -> cut.

Run all : uv run --python 3.12 --with faster-whisper python scripts/03_titles.py
Sample  : set env  TITLES_SAMPLE="02 Timote decouvre les chiffres;07 Timote jardine"
Override: put start,end (seconds into chapter 1) on a row of title_windows.csv, rerun.
Outputs : title_windows.csv , tree/**/<base>.item.mp3 , titles_review.html
"""
import csv, json, os, subprocess, unicodedata, html
from functools import lru_cache
from pathlib import Path
from _config import BUILD, FFMPEG, FFPROBE, RAW_AUDIO, bak_name
TREE_JSON = BUILD / "stories_tree.json"
OVERRIDES = BUILD / "title_windows.csv"
REVIEW = BUILD / "titles_review.html"
SAMPLE = [s.strip() for s in os.environ.get("TITLES_SAMPLE", "").split(";") if s.strip()]
FORCE = {s.strip() for s in os.environ.get("TITLES_FORCE", "").split(";") if s.strip()}
KEEP_EXISTING = os.environ.get("TITLES_KEEP", "1") != "0"   # reuse a clip already on disk

VAD_L, VAD_R = 0.40, 0.28      # generous pad around the matched span (protect the 1st syllable)
LEAD_SIL = 0.15               # clean silence prepended to every clip (soft start, no fade-in)
FOUT = 0.26                   # fade-out only (never fade the start = never eat the attack)


def norm(s):
    s = unicodedata.normalize("NFD", s.lower())
    s = "".join(c if c.isalnum() else " "
               for c in s if unicodedata.category(c) != "Mn")
    return " ".join(s.replace("timothee", "timote").replace("timotee", "timote").split())


def cut_clip(src, ss, dur, out, trim_lead):
    """Extract [ss, ss+dur] from src -> mono 44.1k mp3:
    gentle silence trim, fade-OUT only, then prepend LEAD_SIL of clean silence
    (2-input concat, no adelay -> no muxer dts warnings). Never fades the start."""
    sr = ("aformat=channel_layouts=mono,aresample=44100,"
          + ("silenceremove=start_periods=1:start_threshold=-48dB:start_silence=0.18:detection=peak,"
             if trim_lead else "")
          + "areverse,"
          "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.08:detection=peak,"
          f"afade=t=in:st=0:d={FOUT},areverse,"        # fades the real END
          "apad=pad_dur=0.14")
    fc = (f"[0:a]{sr}[body];"
          f"[1:a]atrim=0:{LEAD_SIL},asetpts=PTS-STARTPTS[lead];"
          f"[lead][body]concat=n=2:v=0:a=1[out]")
    tmp = str(out) + ".tmp.mp3"
    subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y",
                    "-ss", f"{ss:.3f}", "-t", f"{dur:.3f}", "-i", str(src),
                    "-f", "lavfi", "-i", "anullsrc=r=44100:cl=mono",
                    "-filter_complex", fc, "-map", "[out]",
                    "-ar", "44100", "-ac", "1", "-c:a", "libmp3lame", "-b:a", "192k",
                    "-map_metadata", "-1", tmp], check=True)
    Path(tmp).replace(out)


def match_span(words, target):
    """words: [(start,end,norm)]  target: [norm tokens].
    Return (start, end, score, first_word_start, first_word_end) for the best
    in-order sub-run of `words` covering `target`."""
    m = len(target)
    best = (None, None, 0.0, 0.0, 0.0)
    for i in range(len(words)):
        if not (words[i][2] == target[0]
                or (target[0] == "timote" and words[i][2].startswith("timot"))):
            continue
        k, matched, j, end_j = 0, 0, i, i
        while j < len(words) and k < m and j - i < m + 3:
            wt = words[j][2]
            if wt == target[k] or (target[k] == "timote" and wt.startswith("timot")):
                matched += 1
                k += 1
                end_j = j
            j += 1
        score = matched / m
        if score > best[2]:
            best = (words[i][0], words[end_j][1], score, words[i][0], words[i][1])
    return best


def probe_dur(p):
    return float(subprocess.run([FFPROBE, "-v", "error", "-show_entries", "format=duration",
                 "-of", "csv=p=0", str(p)], capture_output=True, text=True).stdout.strip() or 0)


def load_overrides():
    ov = {}
    if OVERRIDES.exists():
        for r in csv.DictReader(OVERRIDES.open(encoding="utf-8-sig")):
            try:
                ov[r["base"]] = (float(r["start"]), float(r["end"]))
            except (ValueError, KeyError, TypeError):
                pass
    return ov


@lru_cache(maxsize=1)
def _whisper():
    """loaded on first real use -- a pure keep-existing run never touches whisper."""
    from faster_whisper import WhisperModel
    print("loading whisper small ...", flush=True)
    return WhisperModel("small", device="cpu", compute_type="int8")


def transcribe(path, clip=None):
    kw = dict(language="fr", word_timestamps=True)
    if clip:
        kw["clip_timestamps"] = clip
    segs, _ = _whisper().transcribe(str(path), **kw)
    out, txt = [], ""
    for s in segs:
        txt += s.text
        for w in s.words:
            out.append((w.start, w.end, norm(w.word)))
    return out, txt.strip()


def run():
    full = json.loads(TREE_JSON.read_text(encoding="utf-8"))
    stories = [s for s in full if s["base"] in SAMPLE] if SAMPLE else full
    if SAMPLE:
        print(f"SAMPLE: {[s['base'] for s in stories]}")
    ov = load_overrides()
    prev_dur = {}                     # last run's clip durations, to skip ffprobe on kept clips
    if OVERRIDES.exists():
        for r in csv.DictReader(OVERRIDES.open(encoding="utf-8-sig")):
            prev_dur[r["base"]] = r.get("dur") or ""
    orphans = [b for b in ov if b not in {s["base"] for s in full}]
    if orphans:
        print(f"!! {len(orphans)} override(s) sans histoire correspondante (slug obsolète ?): "
              + ", ".join(orphans))

    rows = []
    changed = []                      # bases whose clip was (re)cut this run -> need renormalising
    for st in stories:
        base, ch1 = st["base"], st["chapter1"]
        item = Path(st["item_mp3"])
        item.parent.mkdir(parents=True, exist_ok=True)
        target = norm(st["title"]).split()

        # keep a clip already on disk (02_merge preserves them across a recat):
        # no override, not forced -> reuse as-is, no whisper, no ffprobe.
        if KEEP_EXISTING and item.exists() and base not in ov and base not in FORCE:
            fdur = prev_dur.get(base) or probe_dur(item)
            rows.append(dict(base=base, title=st["title"], method="kept", flag="",
                             dur=fdur, heard="(clip inchangé)", item=str(item)))
            print(f"  {'kept':9s} {'':10s} {str(fdur):>4}s  {base}", flush=True)
            continue

        method, src, ws, we, heard = "none", ch1, None, None, ""

        if base in ov:
            ws, we, method = ov[base][0], ov[base][1], "override"
        else:
            w1, _ = transcribe(ch1, clip="0,34")
            m_s, m_e, score, fw_s, fw_e = match_span(w1, target)
            if m_s is not None and score >= 0.6 and 0.4 <= (m_e - m_s) <= 7.0:
                # whisper inflates the 1st title word ("Timote") back into the pause
                # after "presentent"; if it's long, start ~0.75s before its END.
                eff_s = (fw_e - 0.75) if (fw_e - fw_s) > 1.2 else fw_s
                ws, we = max(0.0, eff_s - VAD_L), m_e + VAD_R
                method = f"match{score:.2f}"

        flag = "" if method.startswith("match") or method == "override" else "A_VERIFIER"
        if ws is None:
            ws, we, method, flag = 10.2, 15.6, "GUESS", "A_VERIFIER"

        dur = we - ws
        cut_clip(src, ws, dur, item, trim_lead=True)
        changed.append(base)
        # this clip changed -> drop any stale loudness pristine-backup so 04b re-captures it
        (RAW_AUDIO / bak_name(item)).unlink(missing_ok=True)
        fdur = probe_dur(item)
        # verify + corrective trim: transcribe the clip, cut off dead lead/tail
        wf, heard = transcribe(item)
        if wf:
            lead = wf[0][0]
            tail_gap = fdur - wf[-1][1]
            if lead > 0.45 or tail_gap > 0.55:
                ns = max(0.0, lead - 0.32)          # keep a comfortable runway
                ne = min(fdur, wf[-1][1] + 0.30)
                cut_clip(item, ns, ne - ns, item, trim_lead=False)
                fdur = probe_dur(item)
                wf, heard = transcribe(item)
                method += "+"
        last = norm(st["title"]).split()[-1]
        if flag == "" and last not in norm(heard):
            flag = "titre?"

        rows.append(dict(base=base, title=st["title"], method=method, flag=flag,
                         dur=round(fdur, 2), heard=heard[:140], item=str(item)))
        print(f"  {method:9s} {flag:10s} {fdur:4.1f}s  {base}   [{heard[:60]}]", flush=True)

    # merge results into existing CSV.
    # CRITICAL: never blank out a manual start/end override. The CSV is the
    # hand-tuning surface -- a full run refreshes dur/method/flag/title but
    # MUST carry every existing start,end forward untouched.
    existing = {}
    if OVERRIDES.exists():
        for r in csv.DictReader(OVERRIDES.open(encoding="utf-8-sig")):
            existing[r["base"]] = r
    for r in rows:
        prev = existing.get(r["base"], {})
        existing[r["base"]] = dict(
            base=r["base"],
            start=(prev.get("start") or "").strip(),   # preserve manual override
            end=(prev.get("end") or "").strip(),        # preserve manual override
            dur=r["dur"], method=r["method"], flag=r["flag"], title=r["title"])
    with OVERRIDES.open("w", newline="", encoding="utf-8") as f:
        w = csv.DictWriter(f, ["base", "start", "end", "dur", "method", "flag", "title"])
        w.writeheader()
        for s in full:
            if s["base"] in existing:
                w.writerow({k: existing[s["base"]].get(k, "") for k in w.fieldnames})

    allrows = list(csv.DictReader(OVERRIDES.open(encoding="utf-8-sig")))
    heardmap = {r["base"]: r["heard"] for r in rows}
    doc = ["<!doctype html><meta charset=utf-8><title>Titres Timote</title>",
           "<style>body{font:14px system-ui;margin:20px;max-width:900px}"
           "tr:nth-child(even){background:#f4f4f4}td{padding:6px 10px;vertical-align:top}"
           ".f{color:#b00;font-weight:bold}audio{height:30px;width:230px}</style>",
           f"<h1>Annonces de titre — {len(allrows)} "
           f"({sum(1 for r in allrows if r['flag'])} à vérifier)</h1>",
           "<p>Corriger : <b>start,end</b> (s, dans le chapitre 1) sur la ligne de "
           "<code>title_windows.csv</code>, relancer <code>03_titles.py</code>.</p><table>",
           "<tr><th>#<th>titre<th>méthode<th>durée<th>écoute<th>entendu</tr>"]
    tr = {s["base"]: s for s in full}
    for r in allrows:
        it = Path(tr[r["base"]]["item_mp3"]).as_posix()
        doc.append(f"<tr><td>{html.escape(r['base'])}<td>{html.escape(r['title'])}"
                   f"<td class={'f' if r['flag'] else ''}>{r['method']} {r['flag']}"
                   f"<td>{r['dur']}s<td><audio controls preload=none src='{html.escape(it)}'></audio>"
                   f"<td><small>{html.escape(heardmap.get(r['base'],''))}</small></tr>")
    doc.append("</table>")
    REVIEW.write_text("\n".join(doc), encoding="utf-8")
    print(f"\nOK — {len(rows)} traitées ce run, "
          f"{sum(1 for r in allrows if r['flag'])} à vérifier au total. {REVIEW}")
    if changed:
        pats = ",".join(f"'{Path(tr[b]['item_mp3']).name}'" for b in changed)
        print(f"\n>>> {len(changed)} clip(s) (re)découpé(s) au niveau brut — RENORMALISER :")
        print(f">>>   scripts\\04b_normalize.ps1 -Only {pats}")
        print(">>> puis  scripts\\05_run_spg.ps1")


if __name__ == "__main__":
    run()
