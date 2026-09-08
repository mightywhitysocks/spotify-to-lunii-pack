# `project.json` — reference

The **single source of truth** for a pack build. `scripts/_config.ps1`
(dot-source) and `scripts/_config.py` (import) locate it (env `PACK_CONFIG`
wins, else `_build/project.json`, else `_build/project.example.json`), deep-merge
it over the built-in DEFAULTS, then deep-merge `_build/project.local.json` on top
if present (gitignored, machine-specific — see `tools` below), and expose one
`$Cfg` / `CONFIG` object. Every key below is optional: a near-empty file
(`{"title": "...", "source_dir": ".."}`) already builds a sane flat pack.

`_build/project.json` is the **active** config and is **gitignored** — edit it
freely without polluting the repo. `_build/examples/timote.json` is the committed
worked example (the Timoté pack); `cp examples/timote.json project.json` to
rebuild it. `_build/project.example.json` is a minimal generic template and the
fallback for a fresh checkout.

## Top level

| key | default | meaning |
|---|---|---|
| `title` | `"Mon pack"` | pack title — `tree/metadata.json`, final `<title>.zip` |
| `description` | `""` | `tree/metadata.json` description |
| `lang` | `"fr"` | `tree/metadata.json`, SPG `--lang`, whisper transcription language |
| `nightModeAvailable` | `false` | `tree/metadata.json` |
| `source_dir` | `".."` | folder of source media, **relative to `_build/`** |
| `source_ext` | audio + video list | extensions picked up as source (case-insensitive, no dot). Video is allowed — everything is re-encoded anyway |
| `menu_root_name` | slug of `title` | name of the folder created under `tree/` |
| `slug_prefix` | `""` | prefix for the stable per-story slug (`<prefix><story-key with - >`) |
| `uncategorized_name` | `"Divers"` | category folder for a story matching no `categories[].stories` |

## `filename_pattern` + groups

Regex matched against the file **stem** (no extension), Python `(?P<name>…)`
named-group syntax (PowerShell converts to `(?<name>…)` automatically).

| key | default | meaning |
|---|---|---|
| `filename_pattern` | `^(?P<num>\d+)[\s._-]+(?P<title>.+)$` | must expose a number group and a title group; an optional chapter group merges multi-file stories |
| `num_group` | `"num"` | group name holding the running file number (matched against `discard` keys) |
| `chapter_group` | `"chapter"` | group name holding the chapter index (absent ⇒ single-chapter stories) |
| `title_group` | `"title"` | group name holding the story title |
| `story_key_strip_prefix` | `""` | regex removed from the *accent-stripped, lower-cased* title to form the story key (Timoté: `^timote\s+`) |

Timoté: `^(?P<num>\d+) Timoté - (?:Chapitre (?P<chapter>\d+) - )?(?P<title>.+?)(?: - Timoté)?$`

## `audio` / `merge`

| `audio` key | default | | `merge` key | default |
|---|---|---|---|---|
| `sample_rate` | `44100` | | `lead` | `0.3` (s of silence before the first chapter) |
| `channels` | `1` | | `tail` | `0.6` (s after the last) |
| `codec` | `"libmp3lame"` | | `gap` | `0.8` (s between chapters) |
| `bitrate` | `"256k"` | | `trim_head_db` / `trim_head_window` | `-45` / `0.3` (start-of-story edge) |
| `target_lufs` | `-16` (04b_normalize) | | `trim_tail_db` / `trim_tail_window` | `-45` / `0.3` (end-of-story edge) |
| `target_tp` | `-1.5` (04b_normalize, dBTP) | | `trim_detection` | `"rms"` (`peak`/`rms`, ffmpeg `silenceremove`) |
| | | | `trim_pad` | `0.1` (guard band kept after each trim) |

### Trim de silence — vocabulaire partagé `merge.*` / `titles.*`

`02_merge.ps1` et `03_titles.py::cut_clip()` sont les deux seuls endroits du pipeline qui trimment du silence (`ffmpeg silenceremove`), et partagent depuis ce changement le même schéma de 6 clés — `trim_head_db`/`trim_head_window` (bord de tête), `trim_tail_db`/`trim_tail_window` (bord de fin), `trim_detection` (`peak` ou `rms`), `trim_pad` (durée de silence rajoutée après la coupe, une marge de sécurité pour ne jamais empiéter sur la parole réelle — technique dite du "guard band"). Chaque script garde ses propres valeurs par défaut, adaptées à son usage (voir `## titles` ci-dessous pour celles de `titles.*`).

**Changement de sémantique (issue #4)** : jusqu'ici, `02_merge.ps1` appliquait son seuil de silence à **chaque bord de chaque chapitre**, y compris les jonctions internes entre deux chapitres d'une même histoire — ce qui pouvait manger la première syllabe d'un chapitre suivant. Désormais, `trim_head_*`/`trim_tail_*` ne s'appliquent plus qu'aux **deux bords externes de l'histoire fusionnée** (tout début du premier chapitre, toute fin du dernier) ; les jonctions internes ne sont plus jamais silence-trimmées — elles restent séparées par `gap` (silence numérique pur, inchangé), ce qui suffit à éviter tout clic audible.

`trim_detection` reste sur `"rms"` (comportement ffmpeg par défaut, inchangé) plutôt que `"peak"` : la documentation ffmpeg et la littérature sur la détection d'activité vocale ne convergent pas clairement sur lequel des deux modes évite le mieux de couper une syllabe douce (consonnes fricatives f/s/ch) — changer ce réglage sans preuve n'était pas justifié. Le paramètre reste exposé pour qui veut tester `"peak"` à l'oreille sur ses propres fichiers.

## `discard`

`{ "<num>": "<reason>" }` — files whose `num` group is a key here are dropped
from the inventory. Default `{}`.

## `categories`

Ordered list. **Empty ⇒ flat single-level menu** (all stories directly under
`menu_root_name`, no category screens).

```json
{ "name": "1 Quotidien", "prompt": "Le quotidien.", "icon": "1F3E0",
  "stories": ["fait un gateau", "jardine"] }
```

- `name` — the category folder under `tree/<menu_root_name>/`
- `prompt` — TTS text for `tree/<menu_root_name>/<name>/0-item.mp3` (04_menu_tts)
- `icon` — icon identifier for the category screen (07_icons, `icons.mode="emoji"`):
  a bare OpenMoji hex code (`"1F3E0"`, the default source) or `"<prefix>:<name>"`
  for an extra library declared in `icons.sources` (e.g. `"material:museum"`)
- `stories` — story keys assigned to this category

## `story_icons`

`{ "<story key>": "<icon identifier>" }` — per-story icon (07_icons), same
identifier format as `categories[].icon` above.

## `menu_prompts` / `first_menu_audio_only`

| key | default | meaning |
|---|---|---|
| `menu_prompts.root` | `""` | TTS text for `tree/0-item.mp3` (pack cover) |
| `menu_prompts.category_chooser` | `""` | TTS text for `tree/<menu_root_name>/0-item.mp3` |
| `first_menu_audio_only` | `false` | `true` ⇒ 07_icons deletes `<menu_root_name>/0-item.png` (chooser screen = audio only, no image) |

## `titles`

Spoken-title clip finder (03_titles).

| key | default | meaning |
|---|---|---|
| `mode` | `"off"` | `"detect"` = run the whisper-based finder; `"off"` = no-op (passthrough CSV + review page only) |
| `fuzzy_first_word` | `false` | allow a 5-char prefix match on the first title word (Timoté: `timoté`/`timothée`…) |
| `synonyms` | `{}` | token rewrites applied during normalisation (Timoté: `{"timothee": "timote"}`) |
| `clip_bitrate` | `"192k"` | bitrate of the title clip mp3 |
| `lead` | `0.15` | clean silence prepended to every clip |
| `fade_out` | `0.26` | fade-out length (start is never faded) |
| `vad_l` / `vad_r` | `0.40` / `0.28` | pad left/right of the matched span |
| `trim_head_db` / `trim_head_window` | `-48` / `0.18` | start-of-clip edge trim (see "Trim de silence" under `## audio / merge` — same vocabulary, own defaults) |
| `trim_tail_db` / `trim_tail_window` | `-45` / `0.08` | end-of-clip edge trim |
| `trim_detection` | `"peak"` | `peak`/`rms`, ffmpeg `silenceremove` |
| `trim_pad` | `0.14` | guard band kept after each trim |

The manual-override contract is unchanged: fill `start,end` (seconds into
chapter 1) on a row of `title_windows.csv` and rerun — those values win and are
never blanked by a full run. The run is idempotent: an override row is re-cut
only when its `start,end` differs from the `ov_start,ov_end` the script last cut
from (bookkeeping columns, not meant to be edited); an unchanged override keeps
the clip on disk just like a detected one.

## `icons`

| key | default | meaning |
|---|---|---|
| `mode` | `"off"` | `"emoji"` = generate line icons; `"off"` = no-op (SPG renders text images) |
| `set` | `"black"` | OpenMoji set |
| `url` | OpenMoji raw URL with `{set}` / `{code}` | default icon source template (bare hex codes) |
| `render_bg` | `"0xF6F3EC"` | reportlab raster background before negate |
| `sources` | `{}` | extra icon libraries: `{"<prefix>": "<url template with {code}>"}`, referenced from `categories[].icon`/`story_icons` as `"<prefix>:<name>"` (e.g. `{"material": ".../{code}/materialsymbolsoutlined/{code}_24px.svg"}` used as `"material:museum"`). Cached under `_build/tools/icons/<prefix>/`, separate from the OpenMoji cache — no invalidation across sources or across `set` changes (see issue tracking cache staleness) |

## `covers`

Spotify album-cover fetch (08a) + grayscale treatment (08e).

| key | default | meaning |
|---|---|---|
| `mode` | `"off"` | `"spotify"` = fetch; `"off"` = no-op |
| `bad_album` | `""` | regex; a match subtracts score (compilations, box sets…) |
| `good_artist` | `""` | regex; a match adds score |
| `crop_top` / `crop_bottom` | `0.30` / `0.16` | fraction cropped off the top / bottom before grayscale |

Needs `_build/.spotify` (`CLIENT_ID=…` / `CLIENT_SECRET=…`, git-ignored).
`covers_urls.csv` manual URL overrides still win.

## `pack_cover`

| key | default | meaning |
|---|---|---|
| `mode` | `"none"` | `"none"` = no-op; `"image"` = fit `src` on the canvas + grayscale; `"floodfill"` = flood-fill `bg` transparent, trim, place figure on black + grayscale |
| `src` | `""` | source image, relative to `_build/` |
| `bg` | `"srgb(52,60,132)"` | flood-fill target colour (`floodfill` mode) |
| `fuzz` | `"22%"` | flood-fill fuzz |

## `image`

| key | default | meaning |
|---|---|---|
| `canvas` | `"#0A0D12"` | Lunii screen background for composed images |
| `w` / `h` | `320` / `240` | screen size |
| `fit` | `232` | max size of a centred single subject (07_icons) |

## `tts`

| key | default | meaning |
|---|---|---|
| `engine` | `"piper"` | only `"piper"` is supported |
| `model` | `""` | path to the Piper `.onnx` voice, relative to `_build/` — **required** when any `menu_prompts` / `categories[].prompt` is set |
| `lead` / `tail` | `0.15` / `0.4` | silence around each synthesised prompt |

## `tools`

All optional — a blank value is auto-discovered on `PATH`
(`Get-Command` / `shutil.which`), then among the vendored binaries under
`_build/tools/**`, else the script fails with a clear message.
A relative value is resolved against `_build/`.

Machine-specific, so it never lives in a committed config (`examples/timote.json`
or `project.example.json`): put it in `_build/project.local.json` instead — a
gitignored file, deep-merged on top of `project.json` by both loaders. Copy
`project.local.json.example` to get started.

| key | PATH names tried |
|---|---|
| `ffmpeg` | `ffmpeg` |
| `ffprobe` | `ffprobe` (else sibling of `ffmpeg`) |
| `uv` | `uv` |
| `spg` | `studio-pack-generator`, `studio-pack-generator-x86_64-windows[.exe]`, `-x86_64-linux`, `-aarch64-linux`, `-x86_64-macos`, `-aarch64-macos` |
| `imagemagick` | `magick`, `convert` |
