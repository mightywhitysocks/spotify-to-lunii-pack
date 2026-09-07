"""one-shot: transcribe ch1 of the 4 problem titles, print word timestamps
around the intro so we can pick manual start,end windows."""
import json, sys
from _config import BUILD

WANT = {
    "est malade": None,
    "va au centre de loisirs": None,
    "va au spectacle": None,
    "fait du ski": None,
}
stories = json.loads((BUILD / "stories_tree.json").read_text(encoding="utf-8"))
from faster_whisper import WhisperModel
m = WhisperModel("small", device="cpu", compute_type="int8")
for st in stories:
    if st["key"] not in WANT:
        continue
    print(f"\n===== {st['title']}  ({st['key']}) =====")
    segs, _ = m.transcribe(st["chapter1"], language="fr", word_timestamps=True,
                           clip_timestamps="0,40")
    for s in segs:
        for w in s.words:
            if w.start > 40:
                break
            print(f"  {w.start:6.2f} - {w.end:6.2f}  {w.word!r}")
