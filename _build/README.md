# _build — génération du pack Lunii « Les histoires de Timoté »

Tout est produit ici à partir des 99 MP3 de `..\` (jamais modifiés).

## Outils installés / téléchargés

| Outil | Emplacement | Rôle |
|---|---|---|
| studio-pack-generator 0.5.15 (binaire Deno, ffmpeg + ImageMagick embarqués) | `tools\spg\` | dossier → pack `.zip` Lunii, images de titre, `story.json`, zip |
| Piper 1.8.0 + voix `fr_FR-siwis-medium` | `tools\piper\` | TTS français des prompts de menu |
| faster-whisper (modèle `small`) via `uv` | cache `uv` + `~\.cache\huggingface` | transcription pour localiser l'annonce du titre |
| ffmpeg-normalize 1.42.0 via `uv` | cache `uv` | normalisation loudness EBU R128 (−16 LUFS / −1,5 dBTP) |
| `uv` (Astral) | déjà présent (winget) | exécute les outils Python en environnement isolé (Python 3.12) |
| ffmpeg / ffprobe 8.0 | `C:\Program Files\ffmpeg` (système) | fusion des chapitres, mesures, découpes |

**Chemins centralisés** : `scripts\_config.ps1` (dot-source) et `scripts\_config.py` (import)
définissent une seule fois `build` / `tree` / `rawAudio` / `ffmpeg` / `ffprobe` / `uv`, la
couleur `CANVAS` et `BakName`/`bak_name` (nom d'un backup loudness). Ne plus coder de chemin
en dur. Traitement gris partagé : `_covers.gray_ops()` ; compo sur canvas : `_covers.place_on_canvas()`.
Scripts abandonnés dans `scripts\_deprecated\`.

Rien n'est installé dans le système global : les paquets Python vivent dans le cache `uv`
(`uv cache clean` pour tout supprimer). Modèles téléchargés : whisper `small` (~465 Mo,
cache HuggingFace), voix Piper (~63 Mo, `tools\piper`), binaire SPG (~90 Mo, `tools\spg`).

## Pipeline (scripts\)

| # | Script | Sortie |
|---|---|---|
| 1 | `01_inventory.ps1` | `inventory.csv`, `stories.json`, `categories.csv` — 99 fichiers → 45 histoires |
| 2 | `02_merge.ps1` `[-Rebuild]` | `tree\...\<NN titre>.mp3` — chapitres fusionnés (44,1 kHz mono, silence de bord rogné, 0,8 s entre chapitres) + `stories_tree.json`. **Réconcilie** (ne détruit plus le tree) : ré-utilise chaque clip déjà fusionné et le **déplace** dans son nouveau créneau catégorie/index (+ son `.item.mp3`/`.item.png`/backup loudness). `-Rebuild` = tout re-fusionner. Le champ JSON `base` est le **slug stable** (`timote-…`), indépendant de la catégorie → les clés de `title_windows.csv` / `cover_tune.csv` survivent à une recatégorisation |
| 3 | `03_titles.py` (`uv run --python 3.12 --with faster-whisper`) | `tree\...\<NN titre>.item.mp3` — annonce du titre découpée (silence de garde en tête + fondu de sortie, pas de fondu d'entrée) + `title_windows.csv` (éditable, **les `start,end` manuels sont préservés à chaque run**) + `titles_review.html` |
| 4 | `04_menu_tts.py` (`uv ... --with piper-tts`) | `tree\...\0-item.mp3` × 11 — prompts de menu (Piper `fr_FR-siwis-medium`). Cover + « choisis un thème » = **audio seul, pas d'image** |
| 4b | `04b_normalize.ps1` `[-Only <pat>] [-Fresh]` | `.mp3` du `tree` → −16 LUFS / −1,5 dBTP. **Idempotent** : normalise depuis la copie pristine `work\raw_audio` ; chaque générateur (02/03/04) invalide ses propres backups, donc un re-run est sûr. `-Only` = sous-ensemble ; `-Fresh` = reset paranoïaque |
| 4d | `04d_report.ps1` | `audio_report.csv` — mesure loudness/format |
| 7 | `07_icons.py` (`uv ... --with svglib --with reportlab --with lxml --with rlpycairo`) | pictogrammes OpenMoji N&B (blanc sur near-black, **sans bordure**) pour les **9 thèmes** ; icône École = bâtiment d'école. Supprime l'image du premier menu (« choisis un thème » = audio seul) |
| 7c | `07c_cover.py` | `tree\0-item.png` — image du pack : Timoté détouré de la photo de profil Spotify (`covers/raw/_artist_timote.jpg`, flood-fill du fond indigo), sur fond noir, même traitement gris que les couvertures. Réglage : ligne `slug=_cover` de `cover_tune.csv` |
| 8a | `08a_fetch_covers.py` (`uv ... --with requests`) | pochettes Spotify (1 album/livre) → `covers/raw/<slug>.jpg` 640px ; besoin de `_build\.spotify` (Client ID/Secret) |
| 8e | `08e_grayscale.py` | `covers/gray/<slug>.png` — recadré sur l'illustration (crop 30 %/16 %), gris + CLAHE + contraste sigmoïde, 320×240, **sans bordure**. Réglages : `cover_tune.csv` (optionnel) |
| 8f | `08f_apply.py` | copie les couvertures gris sur les **45 écrans d'histoire** (`style=icon` dans `cover_tune.csv` = garder le pictogramme) |
| 7b | `07b_icons_page.py` | `icons_review.html` — galerie de toutes les images |
| 5 | `05_run_spg.ps1` | `Les histoires de Timoté.zip` — le pack (relancer après tout changement d'asset) |
| 6 | `06_review_page.py` | `titles_review.html` autonome (audio embarqué) |

**Ordre de reconstruction des images** : `07_icons.py` (écrase tous les `.item.png` par des
pictogrammes) **puis** `08f_apply.py` (recopie les couvertures gris sur les 45 histoires) **puis** `05`.

Scripts abandonnés dans `scripts\_deprecated\` : `04_menu_tts.ps1`, `04c_images.ps1`,
`06b_fade.ps1` (les fondus sont dans `03`), `08b/08c/08d` (tracé potrace/vtracer).

## Corriger une annonce de titre

1. Éditer `title_windows.csv` : mettre `start,end` (s, dans le chapitre 1) sur la ligne du
   slug. Ces valeurs **priment** sur la détection et sont **préservées** à chaque run.
2. `03_titles.py` — ne re-découpe que les lignes avec override ou listées dans
   `TITLES_FORCE="slug;slug"` ; les autres clips déjà présents sont **conservés tels quels**
   (pas de whisper). `TITLES_KEEP=0` force la re-détection complète.
3. **Renormaliser les clips re-découpés** (sinon ~4 dB trop forts) : `03_titles.py` affiche
   à la fin la commande exacte `04b_normalize.ps1 -Only '<fichier>',…` (uniquement les clips
   changés).
4. `scripts\05_run_spg.ps1`.

## Changer la catégorisation d'une histoire

Éditer `$catMap` dans `01_inventory.ps1`, puis : `01_inventory.ps1` → `02_merge.ps1`
(réconcilie : déplace les fichiers, ~10 s, pas de ré-encodage) → `03_titles.py` (tout
« kept ») → `07_icons.py` → `08f_apply.py` → `05_run_spg.ps1`. Ni `04`/`04b` ni whisper :
`base` est un slug stable, l'audio et les couvertures suivent l'histoire.

## État final

- **`Les histoires de Timoté.zip`** (≈ 470 Mo) — pack généré par SPG, `story.json` au
  format plat `stageNodes`/`actionNodes` `format:v1 version:1` (lu tel quel par lunii-admin).
- 101 nœuds de scène (couverture + menu + 9 catégories + 45 titres + 45 histoires),
  56 nœuds d'action, **0 problème d'intégrité** (transitions et références d'assets valides,
  `controlSettings` partout, audio sur chaque nœud). 55 nœuds avec image (pack + 9 thèmes +
  45 couvertures) ; seul « choisis un thème » = audio seul, `image:null` (SPG le tolère).
- Navigation : couverture « Les histoires de Timoté » (Timoté détouré) → OK → « Choisis un thème »
  (audio) → molette 9 thèmes → OK → molette des histoires (annonce du titre) → OK →
  l'histoire → fin → retour à la liste du thème.
- Répartition des 9 thèmes : Quotidien 5 · Émotions 7 · École 7 · Sorties 7 · Voyages 3 ·
  Sport 4 · Fêtes 3 · Corps/santé 3 · Nature 6.
- Annonces de titre : 45 clips à **−16 LUFS** (renormalisés — ils étaient auparavant
  ~−12 LUFS et quelques-uns écrêtés).
- Audio : 101 fichiers à **−16 LUFS ± 1** (EBU R128), crête ≤ −1,4 dBFS, 44,1 kHz mono.
  Sources d'origine : −12,4 LUFS et écrêtées (+2,3 dBTP) → l'écrêtage d'origine ne peut pas
  être réparé, mais plus aucun ajout et niveau homogène.
- **3 annonces de titre à réécouter** (whisper transcrit mal les clips de 2 s, mais les
  fenêtres ont été posées d'après les transcriptions des chapitres) :
  `07 fait des betises`, `05 va au centre de loisirs`, `04 joue au foot`.
  → écouter dans `titles_review.html` ; si à corriger, éditer `title_windows.csv` (start,end)
  et relancer `03_titles.py` puis `04b`/`04d`/`05`.

## Installer sur la Lunii

`lunii-admin` → *install pack* → `Les histoires de Timoté.zip`.
(Optionnel : import du zip dans `lunii-admin-builder.pages.dev` pour un aperçu visuel de l'arbre.)
