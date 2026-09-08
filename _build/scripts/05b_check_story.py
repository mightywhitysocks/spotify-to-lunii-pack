r"""
05b_check_story.py  --  integrity check of the story.json produced by SPG.

_build/README.md used to just assert "0 problème d'intégrité" on faith (checked
by hand once). This script actually verifies it: reads story.json out of the
built pack and checks --
  - exactly one entry point (stageNode squareOne=true)
  - controlSettings present on every stageNode, with the 5 expected boolean keys
  - every stageNode has an audio ref, and it resolves to a real file in the pack
  - every image ref (when present) resolves to a real file in the pack
  - every okTransition/homeTransition points at an existing actionNode, at a
    valid index into its options
  - every actionNode option points at an existing stageNode
  - no orphan node: every stageNode/actionNode is reachable from the entry point

Run (no extra deps -- stdlib only):
  uv run --python 3.12 python scripts/05b_check_story.py [pack.zip | extracted_dir]
Default target: the zip 05_run_spg.ps1 just produced (<build>/<title>.zip).
Exit code: 0 if clean, 1 if any problem was found.
"""
import sys
import zipfile
from pathlib import Path

from _config import CONFIG, BUILD

CONTROL_KEYS = {"wheel", "ok", "home", "pause", "autoplay"}


def _default_pack_path() -> Path:
    safe = "".join(c if c not in '<>:"/\\|?*' else " " for c in CONFIG["title"]).strip()
    return BUILD / f"{safe}.zip"


def _load(pack_path: Path):
    """-> (story dict, has_asset(filename) -> bool)."""
    if pack_path.is_dir():
        story = (pack_path / "story.json")
        if not story.exists():
            raise SystemExit(f"story.json introuvable dans {pack_path}")
        import json
        names = {p.name for p in pack_path.rglob("*") if p.is_file()}
        return json.loads(story.read_text(encoding="utf-8")), (lambda f: f in names)

    if not pack_path.exists():
        raise SystemExit(
            f"pack introuvable : {pack_path}\n"
            f"  -> lance scripts\\05_run_spg.ps1 d'abord, ou passe un chemin en argument.")
    with zipfile.ZipFile(pack_path) as z:
        names = z.namelist()
        try:
            raw = z.read("story.json")
        except KeyError:
            raise SystemExit(f"story.json absent du pack : {pack_path}")
        import json
        story = json.loads(raw)
        basenames = {n.rsplit("/", 1)[-1] for n in names}
        return story, (lambda f: f in basenames)


def check(story: dict, has_asset) -> list[str]:
    problems = []
    stage_nodes = story.get("stageNodes")
    action_nodes = story.get("actionNodes")
    if not isinstance(stage_nodes, list):
        return ["stageNodes absent ou invalide"]
    if not isinstance(action_nodes, list):
        return ["actionNodes absent ou invalide"]

    stage_by_uuid, action_by_id = {}, {}
    for n in stage_nodes:
        u = n.get("uuid")
        label = u or n.get("name") or "<sans uuid>"
        if not u:
            problems.append(f"stageNode sans uuid : {label}")
            continue
        if u in stage_by_uuid:
            problems.append(f"uuid de stageNode dupliqué : {u}")
        stage_by_uuid[u] = n
    for a in action_nodes:
        i = a.get("id")
        label = i or a.get("name") or "<sans id>"
        if not i:
            problems.append(f"actionNode sans id : {label}")
            continue
        if i in action_by_id:
            problems.append(f"id d'actionNode dupliqué : {i}")
        action_by_id[i] = a

    entries = [n for n in stage_nodes if n.get("squareOne")]
    if not entries:
        problems.append("aucun nœud squareOne (point d'entrée manquant)")
    elif len(entries) > 1:
        problems.append(f"{len(entries)} nœuds squareOne (un seul attendu)")

    def node_label(n):
        return n.get("name") or n.get("uuid") or "<?>"

    for n in stage_nodes:
        label = node_label(n)
        cs = n.get("controlSettings")
        if not isinstance(cs, dict):
            problems.append(f"{label} : controlSettings absent")
        else:
            missing = CONTROL_KEYS - cs.keys()
            if missing:
                problems.append(f"{label} : controlSettings incomplet (manque {sorted(missing)})")

        audio = n.get("audio")
        if not audio:
            problems.append(f"{label} : pas d'audio")
        elif not has_asset(audio):
            problems.append(f"{label} : asset audio introuvable dans le pack ({audio})")

        image = n.get("image")
        if image and not has_asset(image):
            problems.append(f"{label} : asset image introuvable dans le pack ({image})")

        for tkey in ("okTransition", "homeTransition"):
            t = n.get(tkey)
            if t is None:
                continue
            aid = t.get("actionNode")
            action = action_by_id.get(aid)
            if action is None:
                problems.append(f"{label} : {tkey} pointe vers un actionNode inexistant ({aid})")
                continue
            idx = t.get("optionIndex")
            options = action.get("options") or []
            if not isinstance(idx, int) or not (0 <= idx < len(options)):
                problems.append(f"{label} : {tkey}.optionIndex hors bornes ({idx} / {len(options)} options)")

    for a in action_nodes:
        label = a.get("name") or a.get("id") or "<?>"
        options = a.get("options")
        if not options:
            problems.append(f"actionNode {label} : options vide")
            continue
        for opt in options:
            if opt not in stage_by_uuid:
                problems.append(f"actionNode {label} : option référence un nœud inexistant ({opt})")

    # reachability from the entry point -- no orphan stage/action node
    if len(entries) == 1:
        visited_stages = {entries[0].get("uuid")}
        visited_actions = set()
        stack = [entries[0]]
        while stack:
            n = stack.pop()
            for tkey in ("okTransition", "homeTransition"):
                t = n.get(tkey)
                if not t:
                    continue
                aid = t.get("actionNode")
                action = action_by_id.get(aid)
                if not action or aid in visited_actions:
                    continue
                visited_actions.add(aid)
                for opt in action.get("options") or []:
                    if opt in stage_by_uuid and opt not in visited_stages:
                        visited_stages.add(opt)
                        stack.append(stage_by_uuid[opt])

        for u, n in stage_by_uuid.items():
            if u not in visited_stages:
                problems.append(f"nœud orphelin (inatteignable depuis le point d'entrée) : {node_label(n)}")
        for aid, a in action_by_id.items():
            if aid not in visited_actions:
                label = a.get("name") or aid
                problems.append(f"actionNode orphelin (jamais référencé par une transition) : {label}")

    return problems


def main():
    pack_path = Path(sys.argv[1]) if len(sys.argv) > 1 else _default_pack_path()
    story, has_asset = _load(pack_path)
    problems = check(story, has_asset)

    if not problems:
        n_stages = len(story.get("stageNodes") or [])
        n_actions = len(story.get("actionNodes") or [])
        print(f"OK — 0 problème d'intégrité ({n_stages} nœuds, {n_actions} actions) — {pack_path.name}")
        return
    print(f"{len(problems)} problème(s) d'intégrité dans {pack_path.name} :")
    for p in problems:
        print(f"  ! {p}")
    sys.exit(1)


if __name__ == "__main__":
    main()
