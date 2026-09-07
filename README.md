# spotify-to-lunii-pack

Pipeline pour transformer une série d'histoires audio (99 MP3, ici « Timoté ») en un
pack `.zip` installable sur une conteuse **Lunii**, avec navigation par thèmes,
annonces de titre découpées automatiquement, prompts de menu en TTS et pochettes
récupérées depuis Spotify.

> Ce dépôt ne contient **que le code et la configuration** du pipeline.
> Les fichiers audio, les images, les binaires d'outils et le pack généré sont
> exclus (voir `.gitignore`).

## Vue d'ensemble

99 MP3 de chapitres → 45 histoires → 9 thèmes → pack Lunii (101 nœuds de scène).

| Étape | Script (`_build/scripts/`) | Rôle |
|---|---|---|
| 1 | `01_inventory.ps1` | inventaire, regroupement chapitres → histoires, catégorisation |
| 2 | `02_merge.ps1` | fusion des chapitres, arbre `tree/`, slugs stables |
| 3 | `03_titles.py` | détection + découpe de l'annonce du titre (faster-whisper) |
| 4 | `04_menu_tts.py` | prompts de menu (Piper `fr_FR-siwis-medium`) |
| 4b | `04b_normalize.ps1` | normalisation loudness EBU R128 (−16 LUFS / −1,5 dBTP) |
| 7 | `07_icons.py` | pictogrammes OpenMoji N&B pour les 9 thèmes |
| 7c | `07c_cover.py` | image du pack (Timoté détouré de la photo Spotify) |
| 8a | `08a_fetch_covers.py` | pochettes Spotify (nécessite `_build/.spotify`) |
| 8e / 8f | `08e_grayscale.py`, `08f_apply.py` | traitement gris + application aux écrans |
| 5 | `05_run_spg.ps1` | génération du pack `.zip` (studio-pack-generator) |
| 6 | `06_review_page.py` | page de relecture autonome |

Détail complet, ordre de reconstruction et procédures de correction :
**[`_build/README.md`](_build/README.md)**.

## Prérequis (non versionnés)

- [`studio-pack-generator`](https://github.com/jersou/studio-pack-generator) (binaire Deno) → `_build/tools/spg/`
- [Piper](https://github.com/rhasspy/piper) + voix `fr_FR-siwis-medium` → `_build/tools/piper/`
- `faster-whisper` (modèle `small`) et `ffmpeg-normalize` via [`uv`](https://github.com/astral-sh/uv)
- `ffmpeg` / `ffprobe` 8.0
- [OpenMoji](https://openmoji.org/) (jeu de pictogrammes) → `_build/tools/openmoji/`
- `_build/.spotify` : `CLIENT_ID=…` / `CLIENT_SECRET=…` (Spotify Web API, pour les pochettes)

## Installer le pack généré

`lunii-admin` → *install pack* → `Les histoires de Timoté.zip`.
