# Récap — traitement des issues

Journal du passage sur les issues ouvertes, de la plus simple à la plus complexe.
Un correctif = un commit poussé sur `main`.

## Fait

| Issue | Titre | Résolution | Commit |
|---|---|---|---|
| #42 | 04b et 04d écrivent tous deux `audio_report.csv` | Déjà corrigé par `900d6bd` (PR #44) : 04b → `normalize_report.csv`, 04d → `audio_report.csv`. Issue fermée. | `900d6bd` |
| #41 | `_config` ne détecte pas le binaire SPG vendored dans `_build/tools/` | Fallback ajouté dans `Resolve-Tool` / `_resolve_tool` : après l'échec du PATH, scan de `_build/tools/**` pour un nom connu. Miroir PS/Python. README (Outils + loader) mis à jour. | `41a4d6c` |
| #43 | `03_titles.py` re-découpe les fenêtres à override manuel à chaque run | Colonnes `ov_start,ov_end` dans `title_windows.csv` : mémo de la fenêtre override réellement découpée. Le fast-path « kept » accepte désormais une ligne à override tant que `start,end` == `ov_start,ov_end` ; re-découpe seulement si l'utilisateur a bougé la fenêtre (ou `TITLES_FORCE`). Flag humain conservé sur un override gardé. README + `project.schema.md` à jour. | `674f07c` |
| #26 | Mesure de loudness dupliquée dans 01 / 04b / 04d | Fonction unique `Measure-Loudness` dans `_config.ps1` (une passe ffmpeg `ebur128`, parse `Summary:`). Les trois `Measure-LU` / bloc inline locaux supprimés. Sorties `inventory.csv` / `stories.json` byte-identiques avant/après ; 04d re-vérifié. | `b96b456` |
| #18 | Auto-suggérer l'emoji d'une histoire depuis son titre | Classée (not planned) conformément à la décision attendue dans l'issue : table mots-clés→emoji à maintenir + fuzzy-matching = ROI négatif vs 45 lignes écrites une fois. | — |
| #23 | Séparer l'exemple Timoté de la config active | `_build/project.json` sorti du suivi git (gitignoré) = copie de travail. `git mv` de l'ancien contenu vers `_build/examples/timote.json` (exemple committé de référence). Loaders : fallback `project.json` → `project.example.json` pour un clone frais. README (racine + `_build`) + `project.schema.md` à jour. | _(ce commit)_ |

| #8 | Validation de `project.json` (clés requises, enums de mode, schéma) | Validation légère dans les deux loaders (option recommandée par l'issue) : `*.mode` / `tts.engine` hors énumération → arrêt avec message ; clé inconnue (récursive, hors maps free-form) → warning. `sources` ajouté à `$Defaults.icons` (drift PS/Python corrigé au passage). README + `project.schema.md` à jour. | _(ce commit)_ |

## À suivre (ordre prévu, du plus simple au plus complexe)

- #13 — homogénéiser fail-soft / fail-loud
- #20 — script de récupération de studio-pack-generator
- #3 / #6 — revue et complément de documentation

## Écartées pour l'instant

`needs-decision` / `blocked` / `needs-investigation` : #9, #12, #16, #17, #19, #24,
#27, #28, #21, #5, #10, #11, #7, #14 — nécessitent un arbitrage produit ou une
investigation préalable avant tout code.
