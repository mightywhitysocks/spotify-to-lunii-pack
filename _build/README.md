# `_build` — génération d'un pack Lunii

Pipeline générique, piloté par un seul fichier de config. Tout est produit ici à
partir des fichiers audio de `source_dir` (jamais modifiés).

## Configuration : `project.json`

`scripts/_config.ps1` (dot-source) et `scripts/_config.py` (import) sont des
**loaders** : ils localisent le fichier de config (env `PACK_CONFIG`, sinon
`_build/project.json`), le fusionnent en profondeur par-dessus des valeurs par
défaut, fusionnent par-dessus `_build/project.local.json` s'il existe (gitignoré,
overrides machine — voir « Outils » ci-dessous), résolvent les chemins d'outils
(valeur de config → sinon `Get-Command` / `shutil.which` sur le PATH → sinon
erreur explicite) et exposent un objet unique `$Cfg` / `CONFIG`. Les noms
historiques (`$Cfg.build` / `.tree` / `.src` / `.ffmpeg` … et `BUILD` / `TREE` /
`FFMPEG` …) sont dérivés de la config.

- **Toutes les clés** : [`project.schema.md`](project.schema.md)
- **Exemple minimal générique** : [`project.example.json`](project.example.json)
- **Exemple réel complet** : [`project.json`](project.json) (projet « Timoté » —
  99 MP3 → 45 histoires → 9 thèmes)

Une config quasi vide (`{"title": "…", "source_dir": ".."}`) produit déjà un pack
à plat cohérent : `titles` / `icons` / `covers` / `pack_cover` sont `off` par
défaut, le menu est à plat tant que `categories` est vide.

## Outils

| Outil | Rôle | clé `tools` |
|---|---|---|
| studio-pack-generator (binaire, ffmpeg + ImageMagick embarqués) | dossier → pack `.zip` Lunii, images de titre, `story.json`, zip | `spg` |
| Piper + voix `.onnx` | TTS des prompts de menu | via `tts.model` |
| faster-whisper via `uv` | transcription pour localiser l'annonce du titre | `uv` |
| ffmpeg-normalize via `uv` | normalisation loudness EBU R128 | `uv` |
| ffmpeg / ffprobe | fusion, mesures, découpes | `ffmpeg` / `ffprobe` |

Chaque clé `tools` vide est auto-détectée sur le PATH ; l'auto-détection de SPG
accepte le suffixe de plateforme (`-x86_64-windows`, `-x86_64-linux`,
`-aarch64-macos`, …). Une valeur relative est résolue par rapport à `_build/`.

Ces chemins sont propres à chaque machine : ils ne vont jamais dans `project.json`
(committé), mais dans `_build/project.local.json` — gitignoré, copié depuis
[`project.local.json.example`](project.local.json.example) puis adapté.

## Pipeline (`scripts\`)

| # | Script | Sortie |
|---|---|---|
| 1 | `01_inventory.ps1` | `inventory.csv`, `stories.json`, `categories.csv`. Regex / groupes / clé d'histoire / catégories / `discard` / préfixe de slug / extensions source : tout depuis `$Cfg`. Histoire non mappée → `uncategorized_name`. `categories` vide → `category=""` partout |
| 2 | `02_merge.ps1` `[-Rebuild]` | `tree\…\<NN titre>.mp3` — chapitres fusionnés (rate / layout / codec / bitrate / silences depuis `$Cfg.audio` + `$Cfg.merge`) + `stories_tree.json`. **Réconcilie** (ne détruit pas le tree) : ré-utilise chaque clip déjà fusionné, le **déplace** dans son nouveau créneau (+ `.item.mp3` / `.item.png` / backup loudness). `-Rebuild` = tout re-fusionner. Menu à plat si `categories` vide. `base` (JSON) = slug stable, indépendant de la catégorie |
| 3 | `03_titles.py` (`uv run --with faster-whisper`) | si `titles.mode="detect"` : `tree\…\<NN titre>.item.mp3` + `title_windows.csv` (éditable, `start,end` manuels **préservés**) + `titles_review.html`. Si `off` : CSV passthrough + page, aucun audio touché |
| 4 | `04_menu_tts.py` (`uv … --with piper-tts`) | `tree\…\0-item.mp3` — `menu_prompts.root` → `tree/0-item.mp3`, `menu_prompts.category_chooser` → `<menu>/0-item.mp3`, `categories[].prompt` → `<menu>/<cat>/0-item.mp3`. Prompts de catégorie ignorés en menu à plat ; textes vides ignorés. Erreur claire si `tts.model` absent |
| 4b | `04b_normalize.ps1` `[-Only <pat>] [-Fresh]` | `.mp3` du `tree` → `audio.target_lufs` / `audio.target_tp`. **Idempotent** : normalise depuis la copie pristine `work\raw_audio` ; chaque générateur (02/03/04) invalide ses propres backups |
| 4d | `04d_report.ps1` | `audio_report.csv` — contrôle loudness + format `<sample_rate>,<channels>` |
| 7 | `07_icons.py` (`uv … --with svglib --with reportlab --with lxml`) | si `icons.mode="emoji"` : pictogrammes OpenMoji (blanc sur near-black) pour les thèmes (`categories[].icon`) et les histoires (`story_icons`, clé = clé d'histoire). `first_menu_audio_only` supprime `<menu>/0-item.png` |
| 7c | `07c_cover.py` | selon `pack_cover.mode` : `none` (rien), `image` (place + gris), `floodfill` (détourage flood-fill + gris) → `tree\0-item.png` |
| 8a | `08a_fetch_covers.py` (`uv … --with requests`) | si `covers.mode="spotify"` : pochettes → `covers/raw/<slug>.jpg` ; besoin de `_build\.spotify`. `covers_urls.csv` : override d'URL manuel |
| 8e | `08e_grayscale.py` | `covers/gray/<slug>.png` — recadré (`covers.crop_top` / `crop_bottom`), gris + CLAHE + contraste, `image.w`×`image.h`. Réglages : `cover_tune.csv` |
| 8f | `08f_apply.py` | copie les couvertures gris sur les écrans d'histoire (`style=icon` dans `cover_tune.csv` = garder le pictogramme) |
| 7b | `07b_icons_page.py` | `icons_review.html` — galerie de toutes les images (gère le menu à plat) |
| 5 | `05_run_spg.ps1` | `<title>.zip`. Flags `--skip-*` dérivés : `--skip-audio-convert --skip-audio-item-gen` toujours (on fournit l'audio normalisé) ; `--skip-image-item-gen --skip-extract-image-from-mp-3` seulement si le projet produit ses images (icônes / pochettes / cover). Sinon SPG génère ses propres images de texte |
| 6 | `06_review_page.py` | `titles_review.html` autonome (audio embarqué) |

**Ordre de reconstruction des images** : `07_icons.py` **puis** `08f_apply.py` **puis** `05`.

Scripts abandonnés dans `scripts\_deprecated\`.

## Corriger une annonce de titre (`titles.mode="detect"`)

1. Éditer `title_windows.csv` : mettre `start,end` (s, dans le chapitre 1) sur la
   ligne du slug. Ces valeurs **priment** sur la détection et sont **préservées**.
2. `03_titles.py` — ne re-découpe que les lignes avec override ou listées dans
   `TITLES_FORCE="slug;slug"` ; les autres clips sont **conservés tels quels**.
   `TITLES_KEEP=0` force la re-détection complète.
3. **Renormaliser les clips re-découpés** : `03_titles.py` affiche la commande
   exacte `04b_normalize.ps1 -Only '<fichier>',…`.
4. `scripts\05_run_spg.ps1`.

## Changer la catégorisation d'une histoire

Éditer les listes `categories[].stories` dans `project.json`, puis :
`01_inventory.ps1` → `02_merge.ps1` (réconcilie : déplace les fichiers, pas de
ré-encodage) → `03_titles.py` (tout « kept ») → `07_icons.py` → `08f_apply.py` →
`05_run_spg.ps1`. Ni `04`/`04b` ni whisper : `base` est un slug stable, l'audio
et les couvertures suivent l'histoire.

## Démarrer un nouveau pack

1. Poser les fichiers audio dans un dossier ; pointer `source_dir` dessus.
2. `cp project.example.json project.json`, adapter `title` / `filename_pattern` /
   éventuellement `categories`.
3. Activer les étapes voulues (`titles` / `icons` / `covers` / `pack_cover`).
4. `01_inventory.ps1` → `02_merge.ps1` → étapes actives → `04b_normalize.ps1` → `05_run_spg.ps1`.

## Installer sur la Lunii

`lunii-admin` → *install pack* → `<title>.zip`.
