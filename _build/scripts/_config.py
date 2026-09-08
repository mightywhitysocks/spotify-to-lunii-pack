"""Config loader for the pack build scripts (single source of truth).

Locate the project file (env ``PACK_CONFIG`` wins, else ``_build/project.json``),
deep-merge it over the built-in DEFAULTS, resolve every tool path (config value ->
else ``shutil.which`` on PATH -> else a clear error when the tool is actually used)
and expose a single ``CONFIG`` dict.

The legacy names (``BUILD`` / ``SRC`` / ``TREE`` / ``FFMPEG`` / ``FFPROBE`` / ``UV`` /
``IM`` / ``CANVAS`` / ``RAW_AUDIO`` / ``bak_name``) are still exported, derived from
``CONFIG`` -- so existing ``from _config import BUILD, FFMPEG, ...`` keeps working.

Import from any script in this folder:  from _config import CONFIG, BUILD, FFMPEG, ...
"""
import json
import os
import re
import shutil
import unicodedata
from pathlib import Path

BUILD = Path(__file__).resolve().parent.parent          # ...\<project>\_build
TREE = BUILD / "tree"

# ---------------------------------------------------------------------------
# built-in defaults -- a near-empty project.json ({"title": "...", "source_dir": "..."})
# must already yield sane, generic behaviour through this dict.
# ---------------------------------------------------------------------------
DEFAULTS = {
    "title": "Mon pack",
    "description": "",
    "lang": "fr",
    "nightModeAvailable": False,
    "source_dir": "..",
    "source_ext": ["mp3", "m4a", "m4b", "flac", "ogg", "opus", "wav",
                   "mp4", "m4v", "mkv", "mov", "avi", "webm"],
    "menu_root_name": "",          # empty -> slug of title
    "slug_prefix": "",
    "audio": {
        "sample_rate": 44100, "channels": 1, "codec": "libmp3lame",
        "bitrate": "256k", "target_lufs": -16, "target_tp": -1.5,
    },
    "merge": {"lead": 0.3, "tail": 0.6, "gap": 0.8, "trim_silence_db": -50},
    "filename_pattern": r"^(?P<num>\d+)[\s._-]+(?P<title>.+)$",
    "num_group": "num",
    "chapter_group": "chapter",
    "title_group": "title",
    "story_key_strip_prefix": "",
    "discard": {},
    "categories": [],              # empty -> flat single-level menu
    "uncategorized_name": "Divers",
    "story_icons": {},
    "menu_prompts": {"root": "", "category_chooser": ""},
    "first_menu_audio_only": False,
    "titles": {
        "mode": "off",             # "detect" | "off"
        "fuzzy_first_word": False,
        "synonyms": {},
        "strip_key_word": "",
        "clip_bitrate": "192k",
        "lead": 0.15, "fade_out": 0.26, "vad_l": 0.40, "vad_r": 0.28,
    },
    "icons": {
        "mode": "off",             # "emoji" | "off"
        "set": "black",
        "url": "https://raw.githubusercontent.com/hfg-gmuend/openmoji/master/{set}/svg/{code}.svg",
        "render_bg": "0xF6F3EC",
        "sources": {},             # extra icon libraries: {"prefix": "url template with {code}"}
    },
    "covers": {
        "mode": "off",             # "spotify" | "off"
        "bad_album": "", "good_artist": "",
        "crop_top": 0.30, "crop_bottom": 0.16,
    },
    "pack_cover": {
        "mode": "none",            # "none" | "image" | "floodfill"
        "src": "", "bg": "srgb(52,60,132)", "fuzz": "22%",
    },
    "image": {"canvas": "#0A0D12", "w": 320, "h": 240, "fit": 232},
    "tts": {"engine": "piper", "model": "", "lead": 0.15, "tail": 0.4},
    "tools": {"ffmpeg": "", "ffprobe": "", "uv": "", "spg": "", "imagemagick": ""},
}

# platform-specific studio-pack-generator executable names, for PATH auto-discovery
SPG_NAMES = [
    "studio-pack-generator",
    "studio-pack-generator-x86_64-windows.exe",
    "studio-pack-generator-x86_64-windows",
    "studio-pack-generator-x86_64-linux",
    "studio-pack-generator-aarch64-linux",
    "studio-pack-generator-x86_64-macos",
    "studio-pack-generator-aarch64-macos",
]


def slugify(s: str) -> str:
    """NFD, drop combining marks, non-alphanumerics -> single spaces, trim."""
    n = unicodedata.normalize("NFD", s)
    a = "".join(c for c in n if unicodedata.category(c) != "Mn")
    return re.sub(r"[^A-Za-z0-9]+", " ", a).strip()


def _deep_merge(base, over):
    """Recursively merge ``over`` onto a copy of ``base``. Dicts merge key by key;
    lists and scalars replace."""
    if isinstance(base, dict) and isinstance(over, dict):
        out = dict(base)
        for k, v in over.items():
            out[k] = _deep_merge(base.get(k), v) if k in base else v
        return out
    return over


def _config_path() -> Path:
    env = os.environ.get("PACK_CONFIG")
    return Path(env) if env else BUILD / "project.json"


def _load():
    path = _config_path()
    user = {}
    if path.exists():
        user = json.loads(path.read_text(encoding="utf-8"))
    cfg = _deep_merge(DEFAULTS, user)
    # machine-specific overrides (tool paths, ...) -- gitignored, never committed,
    # always at _build/project.local.json regardless of PACK_CONFIG. See
    # project.local.json.example.
    local_path = BUILD / "project.local.json"
    if local_path.exists():
        local = json.loads(local_path.read_text(encoding="utf-8"))
        cfg = _deep_merge(cfg, local)
    if not cfg.get("menu_root_name"):
        cfg["menu_root_name"] = slugify(cfg["title"])
    if not cfg["tts"].get("lead"):
        cfg["tts"]["lead"] = DEFAULTS["tts"]["lead"]
    cfg["_path"] = str(path)
    cfg["_exists"] = path.exists()
    cfg["_local_path"] = str(local_path)
    return cfg


CONFIG = _load()

SRC = (BUILD / CONFIG["source_dir"]).resolve()           # the folder of source media
MENU = TREE / CONFIG["menu_root_name"]
CANVAS = CONFIG["image"]["canvas"]
RAW_AUDIO = BUILD / "work" / "raw_audio"                  # 04b_normalize's loudness backups


def _resolve_tool(key, *path_names):
    """config value (absolute, or relative to _build/) -> else PATH lookup on
    *path_names -> else the bare name (a later call fails with a clear OS error)."""
    val = (CONFIG["tools"].get(key) or "").strip()
    if val:
        p = Path(val)
        if not p.is_absolute():
            p = BUILD / val
        return str(p)
    for name in path_names:
        found = shutil.which(name)
        if found:
            return found
    return path_names[0] if path_names else key


FFMPEG = _resolve_tool("ffmpeg", "ffmpeg")
if (CONFIG["tools"].get("ffprobe") or "").strip():
    FFPROBE = _resolve_tool("ffprobe", "ffprobe")
elif (CONFIG["tools"].get("ffmpeg") or "").strip():
    FFPROBE = str(Path(FFMPEG).with_name(Path(FFMPEG).name.replace("ffmpeg", "ffprobe")))
else:
    FFPROBE = _resolve_tool("ffprobe", "ffprobe")
UV = _resolve_tool("uv", "uv")
IM = _resolve_tool("imagemagick", "magick", "convert")
SPG = _resolve_tool("spg", *SPG_NAMES)


def require_tool(path, label):
    """Raise a friendly error if ``path`` is not a runnable command."""
    if os.path.sep in str(path) or (os.altsep and os.altsep in str(path)):
        if not Path(path).exists():
            raise SystemExit(
                f"{label} introuvable : {path}\n"
                f"  -> renseigne tools dans {CONFIG['_local_path']} (voir "
                f"project.local.json.example) ou ajoute {label} au PATH.")
    elif shutil.which(str(path)) is None:
        raise SystemExit(
            f"{label} introuvable sur le PATH ({path})\n"
            f"  -> renseigne tools dans {CONFIG['_local_path']} (voir "
            f"project.local.json.example) ou installe {label}.")
    return str(path)


def source_files(folder=None):
    """Every file under ``folder`` (default SRC) whose extension is in source_ext,
    sorted by name."""
    folder = Path(folder or SRC)
    exts = {"." + e.lower().lstrip(".") for e in CONFIG["source_ext"]}
    return sorted((p for p in folder.iterdir()
                   if p.is_file() and p.suffix.lower() in exts),
                  key=lambda p: p.name)


def bak_name(p) -> str:
    """key of a tree audio file in RAW_AUDIO: '<parent dir>__<file name>'.
    Mirror of BakName in _config.ps1 -- keep the two in sync."""
    p = Path(p)
    return f"{p.parent.name}__{p.name}"


def resolve_tree_path(raw) -> Path:
    """Re-anchor a path stored in stories_tree.json under the local TREE.

    02_merge.ps1 now writes story_mp3/item_mp3/item_png relative to its tree
    dir, but a stories_tree.json produced by an older version of the script
    (or moved from another machine) can still hold an absolute path, Windows
    backslashes included. Keep only the portion after the 'tree' folder
    segment when present (that folder's own fixed name) and rebuild it under
    the local TREE, regardless of the separator or platform it was written
    with -- a purely relative path has no such segment and is joined onto
    TREE as-is.
    """
    parts = [p for p in re.split(r"[\\/]+", str(raw)) if p]
    if "tree" in parts:
        parts = parts[parts.index("tree") + 1:]
    return TREE.joinpath(*parts)
