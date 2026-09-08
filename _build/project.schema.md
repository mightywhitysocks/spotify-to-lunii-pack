# `project.json` — reference

The **single source of truth** for a pack build. `scripts/_config.ps1`
(dot-source) and `scripts/_config.py` (import) locate it (env `PACK_CONFIG`
wins, else `_build/project.json`), deep-merge it over the built-in DEFAULTS and
expose one `$Cfg` / `CONFIG` object. Every key below is optional: a near-empty
file (`{"title": "...", "source_dir": ".."}`) already builds a sane flat pack.

`_build/project.json` (Timoté) is the worked example; `_build/project.example.json`
is a minimal generic template.

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
| `bitrate` | `"256k"` | | `trim_silence_db` | `-50` (edge-silence threshold) |
| `target_lufs` | `-16` (04b_normalize) | | | |
| `target_tp` | `-1.5` (04b_normalize, dBTP) | | | |

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
- `icon` — OpenMoji hex code for the category screen (07_icons, `icons.mode="emoji"`)
- `stories` — story keys assigned to this category

## `story_icons`

`{ "<story key>": "<emoji hex>" }` — per-story OpenMoji code (07_icons).

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

The manual-override contract is unchanged: fill `start,end` (seconds into
chapter 1) on a row of `title_windows.csv` and rerun — those values win and are
never blanked by a full run.

## `icons`

| key | default | meaning |
|---|---|---|
| `mode` | `"off"` | `"emoji"` = generate OpenMoji line icons; `"off"` = no-op (SPG renders text images) |
| `set` | `"black"` | OpenMoji set |
| `url` | OpenMoji raw URL with `{set}` / `{code}` | icon source template |
| `render_bg` | `"0xF6F3EC"` | reportlab raster background before negate |

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
(`Get-Command` / `shutil.which`), else the script fails with a clear message.
A relative value is resolved against `_build/`.

| key | PATH names tried | Timoté value |
|---|---|---|
| `ffmpeg` | `ffmpeg` | `C:\Program Files\ffmpeg\bin\ffmpeg.exe` |
| `ffprobe` | `ffprobe` (else sibling of `ffmpeg`) | `…\ffprobe.exe` |
| `uv` | `uv` | WinGet Packages `uv.exe` |
| `spg` | `studio-pack-generator`, `studio-pack-generator-x86_64-windows[.exe]`, `-x86_64-linux`, `-aarch64-linux`, `-x86_64-macos`, `-aarch64-macos` | `tools/spg/Studio-Pack-Generator/studio-pack-generator-x86_64-windows.exe` |
| `imagemagick` | `magick`, `convert` | `tools/spg/Studio-Pack-Generator/tools/convert.exe` |
