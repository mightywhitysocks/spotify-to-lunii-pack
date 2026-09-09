# Récap — traitement des issues

Journal du passage sur les issues ouvertes, de la plus simple à la plus complexe.
Un correctif = un commit poussé sur `main`.

## Fait

| Issue | Titre | Résolution | Commit |
|---|---|---|---|
| #42 | 04b et 04d écrivent tous deux `audio_report.csv` | Déjà corrigé par `900d6bd` (PR #44) : 04b → `normalize_report.csv`, 04d → `audio_report.csv`. Issue fermée. | `900d6bd` |
| #41 | `_config` ne détecte pas le binaire SPG vendored dans `_build/tools/` | Fallback dans `Resolve-Tool` / `_resolve_tool` : après l'échec du PATH, scan de `_build/tools/**` pour un nom connu. Miroir PS/Python. README (Outils + loader) à jour. | `41a4d6c` |
| #43 | `03_titles.py` re-découpe les fenêtres à override manuel à chaque run | Colonnes `ov_start,ov_end` dans `title_windows.csv` : mémo de la fenêtre override réellement découpée. Le fast-path « kept » accepte une ligne à override tant que `start,end` == `ov_start,ov_end` ; re-découpe seulement si l'utilisateur a bougé la fenêtre (ou `TITLES_FORCE`). Flag humain conservé sur un override gardé. README + `project.schema.md` à jour. | `674f07c` |
| #26 | Mesure de loudness dupliquée dans 01 / 04b / 04d | Fonction unique `Measure-Loudness` dans `_config.ps1` (une passe ffmpeg `ebur128`, parse `Summary:`). Les trois implémentations locales supprimées. `inventory.csv` / `stories.json` byte-identiques avant/après ; 04d re-vérifié. | `b96b456` |
| #18 | Auto-suggérer l'emoji d'une histoire depuis son titre | Classée (not planned) selon la décision attendue dans l'issue : table mots-clés→emoji à maintenir + fuzzy-matching = ROI négatif vs ~45 lignes écrites une fois. | — |
| #23 | Séparer l'exemple Timoté de la config active | `_build/project.json` gitignoré = copie de travail. `git mv` de l'ancien contenu vers `_build/examples/timote.json` (exemple committé de référence). Loaders : fallback `project.json` → `project.example.json` pour un clone frais. README (racine + `_build`) + `project.schema.md` à jour. | `92d18f4` |
| #8 | Validation de `project.json` (clés requises, enums de mode, schéma) | Validation légère dans les deux loaders (option recommandée) : `*.mode` / `tts.engine` hors énumération → arrêt ; clé inconnue (récursive, hors maps free-form) → warning. `sources` ajouté à `$Defaults.icons` (drift PS/Python corrigé). README + `project.schema.md` à jour. | `d57ea64` |
| #13 | Homogénéiser fail-soft / fail-loud | Classée (not planned) : aucun échec silencieux concret non traité (icônes → #30, typo config → #8, outils manquants déjà fail-loud). | — |
| #20 | Script de récupération de studio-pack-generator (version épinglée + checksum) | `scripts/get_spg.ps1` : SPG v0.5.15 depuis les releases `jersou/studio-pack-generator`, SHA-256 épinglé par plateforme (digests GitHub), dézip dans `_build/tools/spg/`. Détection de plateforme, `-Force`, no-op si déjà présent. Testé bout-en-bout (download + checksum + extraction, ~5 s). README racine + `_build`. | `152025d` |
| #7 | CI GitHub Actions : lint + compile + validation de config | Workflow minimal (option recommandée, débloquée par #8) : `.github/workflows/ci.yml` — `py_compile` de tous les `.py`, parse de tous les `.ps1` via `Parser::ParseFile`, chargement de `_config.py` + dot-source de `_config.ps1` (fallback `project.example.json`). Pas de `ruff` / `PSScriptAnalyzer`. Run vert vérifié. | `160cac5` |
| #3 (partiel) | Revue de la documentation | Clé fantôme `titles.strip_key_word` supprimée : dans `DEFAULTS` (PS + Python) et posée dans `examples/timote.json` depuis le refactor #1, lue par aucun script. Le reste de #3 (audit complet doc / défauts / altitude) reste ouvert. | `22b9149` |
| #27 | Normalisation loudness en lot au lieu d'un `uv tool run` par fichier | **Mesuré** : run complet 101 fichiers = 9 min 54 s ; le spawn `uv` = 0,47 s × 101 ≈ 47 s (~8 % du total), le reste = les 2 passes internes de `ffmpeg-normalize` (irréductible sans parallélisme). Batcher ne gagne que ~8 % et complique la gestion d'erreur + la limite de ligne de commande Windows ; l'itération passe déjà par `-Only` (2 fichiers ≈ 22 s). **Retenu** : `04b` lit les valeurs « avant » de `ffmpeg-normalize --print-stats` (sa passe 1 mesure déjà l'entrée pristine) au lieu d'une passe ffmpeg dédiée → −44 s (~7 %), zéro perte de précision. | _(ce commit)_ |

**Bilan : 11 issues fermées (#42, #41, #43, #26, #18, #23, #8, #13, #20, #7, #27)**,
plus un correctif partiel sur #3. La doc (README racine + `_build/README` +
`project.schema.md`) a été maintenue à chaque correctif.

Passe `/simplify` sur l'ensemble du lot (`e781218`) : dédup et allègement du code
touché (03_titles, `_config.*`, get_spg), sans changement de comportement.

## Restent ouvertes

Toutes `needs-decision` / `blocked` / `needs-investigation`, ou gros chantiers
nécessitant un arbitrage produit / du matériel Lunii / plusieurs jours :

- **Doc / audio** : #3 (audit doc complet), #6 (audio cible + tests A/B sur la conteuse)
- **Investigation avant code** : #14 (cache whisper — bloqué par #16), #9 (harness de test e2e)
- **Décision produit** : #16 (titres en TTS), #17 (meilleure détection titre), #19 (scoring pochettes), #21 (se passer de SPG), #28 (pré-gain par chapitre), #5 (Spytify)
- **Gros refactors** : #10 (Linux/macOS), #11 (tout-Python), #12 (orchestrateur), #24 (disposition du dépôt)
