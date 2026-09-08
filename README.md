# spotify-to-lunii-pack

Pipeline **générique** pour transformer un dossier de fichiers audio (n'importe
quel conteneur : mp3 / m4a / m4b / flac / ogg / opus / wav — et vidéo, toujours
ré-encodée) en un pack `.zip` installable sur une conteuse **Lunii** : navigation
par thèmes ou menu à plat, annonces de titre découpées automatiquement, prompts
de menu en TTS, pictogrammes, pochettes.

Tout ce qui est spécifique à un projet vit dans **un seul fichier de config**,
`_build/project.json`. Les scripts ne contiennent plus aucune valeur en dur.

> Ce dépôt ne contient **que le code et la configuration**. Les fichiers audio,
> les images, les binaires d'outils et le pack généré sont exclus (`.gitignore`).

## Licence et usage

Le **code** de ce dépôt est distribué sous licence [MIT](LICENSE).

Cette licence ne porte que sur le code : **aucun média** (fichiers audio,
pochettes, illustrations) n'est distribué avec ce dépôt, ni ne doit l'être —
ce sont des contenus tiers destinés à un usage **strictement personnel et
familial** (packs Lunii pour un usage domestique). Les pictogrammes OpenMoji
utilisés par le pipeline restent sous licence CC BY-SA 4.0 avec attribution
(voir [Prérequis](#prérequis-non-versionnés)).

## Pipeline

| Étape | Script (`_build/scripts/`) | Rôle |
|---|---|---|
| 1 | `01_inventory.ps1` | inventaire, regroupement chapitres → histoires, catégorisation |
| 2 | `02_merge.ps1` | fusion des chapitres → arbre `tree/`, slugs stables |
| 3 | `03_titles.py` | découpe de l'annonce du titre (faster-whisper) — si `titles.mode="detect"` |
| 4 | `04_menu_tts.py` | prompts de menu (Piper) |
| 4b | `04b_normalize.ps1` | normalisation loudness EBU R128 |
| 4d | `04d_report.ps1` | mesure loudness/format → `audio_report.csv` |
| 7 | `07_icons.py` | pictogrammes OpenMoji — si `icons.mode="emoji"` |
| 7b | `07b_icons_page.py` | galerie de relecture des images |
| 7c | `07c_cover.py` | image du pack — si `pack_cover.mode` ≠ `none` |
| 8a | `08a_fetch_covers.py` | pochettes Spotify — si `covers.mode="spotify"` |
| 8e / 8f | `08e_grayscale.py`, `08f_apply.py` | traitement gris + application aux écrans |
| 5 | `05_run_spg.ps1` | génération du pack `.zip` (studio-pack-generator) |
| 5b | `05b_check_story.py` | contrôle d'intégrité du `story.json` du pack généré |
| 6 | `06_review_page.py` | page de relecture autonome des annonces de titre |

Détail complet, config et procédures de correction : **[`_build/README.md`](_build/README.md)**
et **[`_build/project.schema.md`](_build/project.schema.md)**.

## Démarrer un nouveau pack

1. Poser les fichiers audio dans un dossier (par défaut le parent de `_build/`).
2. Copier `_build/project.example.json` vers `_build/project.json` et l'adapter :
   au minimum `title`, `source_dir`, `filename_pattern`. Sans `categories` le menu
   est **à plat**. Voir `_build/project.schema.md` pour toutes les clés.
3. Renseigner les outils manquants du PATH dans `_build/project.local.json`
   (copier `_build/project.local.json.example` — gitignoré, propre à chaque
   machine ; ou laisser vide pour auto-détection).
4. Lancer `01_inventory.ps1` → `02_merge.ps1` → (`03`/`04`/`07`/`08…` selon les
   modes activés) → `04b_normalize.ps1` → `05_run_spg.ps1`.

`PACK_CONFIG=<chemin>` permet de pointer un autre fichier de config.

## Prérequis (non versionnés)

- [`studio-pack-generator`](https://github.com/jersou/studio-pack-generator) → `_build/tools/spg/` (ou sur le PATH)
- [Piper](https://github.com/rhasspy/piper) + une voix `.onnx` → `tts.model`
- `faster-whisper` et `ffmpeg-normalize` via [`uv`](https://github.com/astral-sh/uv)
- `ffmpeg` / `ffprobe`
- [OpenMoji](https://openmoji.org/) si `icons.mode="emoji"` (cache `_build/tools/openmoji/<set>/`)
  — pictogrammes sous licence [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) : *"All emojis designed by OpenMoji – the open-source emoji and icon project. License: CC BY-SA 4.0"* (voir [`docs/decisions/0001-openmoji-icons-evaluation.md`](docs/decisions/0001-openmoji-icons-evaluation.md))
- [Material Symbols](https://github.com/google/material-design-icons) (licence Apache 2.0, pas d'attribution requise) pour les icônes `icons.sources.material` — cache `_build/tools/icons/material/` (voir [`docs/decisions/0002-icones-ui-multi-bibliotheques.md`](docs/decisions/0002-icones-ui-multi-bibliotheques.md))
- `_build/.spotify` (`CLIENT_ID=…` / `CLIENT_SECRET=…`) si `covers.mode="spotify"`

## Installer le pack généré

`lunii-admin` → *install pack* → `<title>.zip`.
