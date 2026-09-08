# Récap — traitement des issues

Journal du passage sur les issues ouvertes, de la plus simple à la plus complexe.
Un correctif = un commit poussé sur `main`.

## Fait

| Issue | Titre | Résolution | Commit |
|---|---|---|---|
| #42 | 04b et 04d écrivent tous deux `audio_report.csv` | Déjà corrigé par `900d6bd` (PR #44) : 04b → `normalize_report.csv`, 04d → `audio_report.csv`. Issue fermée. | `900d6bd` |
| #41 | `_config` ne détecte pas le binaire SPG vendored dans `_build/tools/` | Fallback ajouté dans `Resolve-Tool` / `_resolve_tool` : après l'échec du PATH, scan de `_build/tools/**` pour un nom connu. Mirroir PS/Python. README (Outils + loader) mis à jour. | _(ce commit)_ |

## À suivre (ordre prévu, du plus simple au plus complexe)

- #43 — `03_titles.py` non idempotent sur les fenêtres à override manuel
- #26 — factoriser la mesure de loudness (01 / 04b / 04d)
- #18 — auto-suggérer l'emoji d'une histoire depuis son titre
- #23 — séparer l'exemple Timoté de la config active
- #8  — validation de `project.json`
- #13 — homogénéiser fail-soft / fail-loud
- #20 — script de récupération de studio-pack-generator
- #3 / #6 — revue et complément de documentation

## Écartées pour l'instant

`needs-decision` / `blocked` / `needs-investigation` : #9, #12, #16, #17, #19, #24,
#27, #28, #21, #5, #10, #11, #7, #14 — nécessitent un arbitrage produit ou une
investigation préalable avant tout code.
