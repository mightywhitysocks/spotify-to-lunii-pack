# 0002 — Élargir le vocabulaire d'icônes à des bibliothèques UI (au-delà des emoji)

**Statut** : Accepté
**Date** : 2026-09-08
**Complète** : [0001-openmoji-icons-evaluation.md](0001-openmoji-icons-evaluation.md)
**Issue** : [#2](https://github.com/mightywhitysocks/spotify-to-lunii-pack/issues/2)

## Contexte

La décision [0001](0001-openmoji-icons-evaluation.md) évaluait le set OpenMoji et concluait à une approche hybride *entre jeux d'emoji* (OpenMoji conservé, 2 codes remplacés par d'autres codes emoji). Trois cas y restaient documentés comme « limite du vocabulaire Unicode, pas de meilleure alternative à l'époque » : `1F3DB` (musée d'Orsay), `1F5BC` (Louvre), `1F5FC` (tour/Paris) — le vocabulaire emoji n'a tout simplement pas de code dédié pour ces concepts, il faut détourner un glyphe générique.

Le vocabulaire Unicode n'est pas le seul disponible. Des bibliothèques d'**icônes UI** (pas des jeux d'emoji) — Material Symbols, Lucide, Tabler, Font Awesome — couvrent des concepts absents d'Unicode avec un nom exact et non ambigu (`museum`, `theater_comedy`, `construction`...). Cette décision élargit la recherche à ces bibliothèques et documente le résultat d'un balayage systématique des 50 icônes du pack, pas seulement des 3 cas déjà signalés.

## Recherche préalable

| Bibliothèque | Licence | Attribution | Format |
|---|---|---|---|
| Material Symbols (Google) | Apache 2.0 | Non | SVG individuels par nom, `raw.githubusercontent.com/google/material-design-icons/.../{name}_24px.svg` |
| Lucide | ISC | Non | SVG individuels, `stroke="currentColor"` |
| Tabler Icons | MIT | Non | SVG individuels, `stroke="currentColor"` |
| Font Awesome Free | icônes CC BY 4.0 (attribution requise), code MIT | Oui | SVG individuels par style |

Vérifié sur les fichiers réels (pas supposé) : OpenMoji et Material ont des couleurs en dur (`stroke`/`fill` explicites), Lucide et Tabler utilisent `currentColor` — non résolu par `svglib` (pas de cascade CSS), donc risque de trait invisible si non traité en amont.

Confirmé également : ces bibliothèques ont un vocabulaire de **visages/émotions très pauvre** comparé aux emoji (Material n'a que des `sentiment_*` abstraits, rien d'équivalent à « smiling face with horns »). Les 5 usages emoji-visage du pack (`1F60A`, `1F498`, `1F912`, `1F608`) n'ont donc pas d'alternative UI et restent inchangés — c'est le principe même de l'approche hybride : icônes UI pour lieux/objets/actions à nom Unicode absent, emoji conservés pour les visages/émotions.

## Méthode

Même exigence qu'en 0001 : aucun remplacement décidé sur le seul nom d'une icône. Chaque candidat a été téléchargé et rendu via le pipeline réel (320×240, même négatif, même canvas) avant comparaison visuelle à l'original.

## Résultat du balayage

**Seul remplacement retenu : `1F3DB` (musée d'Orsay) → `material:museum`.** Le pictogramme Material (bâtiment à colonnes avec un « M » explicite) est immédiatement identifiable comme « musée », contrairement au bâtiment classique générique d'OpenMoji — gain net confirmé au rendu.

Tous les autres candidats testés ont été **rejetés sur preuve**, pas par manque d'essai :

| Candidat testé | Pour | Verdict | Raison |
|---|---|---|---|
| `material:museum` (2ᵉ usage) | `1F5BC` Louvre | Rejeté | Aurait rendu Louvre et Orsay visuellement identiques (même pictogramme) — les deux codes OpenMoji actuels existent précisément pour rester distincts dans le sélecteur d'histoires. `1F5BC` (cadre encadré) reste **inchangé**, déjà bien distinct de `material:museum` |
| `material:palette` | `1F5BC` Louvre | Rejeté | Identique visuellement à `1F3A8` déjà utilisé pour « va au centre de loisirs » — aurait introduit une collision avec une icône existante du pack |
| `lucide:landmark` / `tabler:building-monument` | `1F5FC` visite Paris | Rejeté | Ni l'un ni l'autre ne représente mieux une tour/monument parisien que l'original (obélisque générique ou bâtiment à colonnes, ce dernier en plus trop proche visuellement de `material:museum`). Aucune bibliothèque testée n'a de nom « eiffel_tower » — `1F5FC` reste **inchangé**, limite confirmée du vocabulaire disponible (emoji et UI) |
| `material:local_library` / `tabler:books` | `1F4DA` bibliothèque | Rejeté | Pas de gain net sur la pile de livres actuelle ; `local_library` (livre ouvert stylisé) se rapproche visuellement de `1F4D6` (livre ouvert, déjà utilisé pour « apprend l'anglais ») — risque de confusion introduit sans bénéfice. `1F4DA` reste **inchangé** |
| `material:construction` | `1F6A7` le chantier | Rejeté | Le pictogramme Material (marteau et clé croisés) évoque l'outillage/la réparation, pas un chantier — moins littéral que le panneau de signalisation actuel, qui est un symbole conventionnel déjà bien identifiable (y compris par un enfant qui le croise dans la rue). `1F6A7` reste **inchangé** |
| — | `1F3A8` centre de loisirs | Vérifié, inchangé | Aucun nom d'icône UI dédié trouvé pour ce concept |
| — | `1F60A`, `1F498`, `1F912`, `1F608` (visages/émotions, 5 usages) | Vérifié, inchangé | Confirmé : aucune bibliothèque UI n'a d'équivalent expressif à ces emoji |
| — | `1F3AD` va au spectacle (déjà réglé par 0001) | Non retesté | Le remplacement emoji→emoji de 0001 a déjà réglé le problème sémantique à coût nul ; migrer vers `material:theater_comedy`/`tabler:theater` n'aurait apporté aucun gain de lisibilité, seulement une dépendance externe en plus |
| — | Reste des 50 icônes (école, hôpital, trottinette, vélo, maison, etc.) | Vérifié, inchangé | Concepts déjà littéraux avec l'emoji actuel, aucun cas surprise trouvé |

**Mise à jour explicite du tableau « Cas examinés et non modifiés » de 0001** : la ligne `1F3DB` de ce tableau est supersédée par la présente décision (remplacé par `material:museum`). Les lignes `1F5BC` et `1F5FC` de 0001 restent valides telles quelles — leur limite documentée en 0001 (pas de meilleure alternative disponible) est confirmée, cette fois sur la base d'un vocabulaire élargi aux bibliothèques UI, pas seulement Unicode.

## Décision technique — support multi-source dans le pipeline

Pour permettre ce remplacement ciblé sans migrer tout le pack, le pipeline (`_build/scripts/07_icons.py`, `_config.py`) a été étendu :

- **Format d'identifiant** : `"<prefix>:<name>"` (ex. `"material:museum"`). L'absence de `:` garde le comportement legacy (code hex OpenMoji nu) — **zéro migration** sur les 49 autres codes du pack.
- **`icons.sources`** (nouvelle clé, `{}` par défaut) : `{"<prefix>": "<url template avec {code}>"}`, déclarée uniquement pour les préfixes effectivement utilisés (seul `material` l'est actuellement).
- **Cache namespacé par source** : `_build/tools/icons/<prefix>/`, distinct du cache OpenMoji existant (`_build/tools/openmoji/`) qui reste inchangé — pas de risque de collision entre bibliothèques.
- **`currentColor`** : réécrit en `#000000` au téléchargement pour toute source non-OpenMoji (no-op pour OpenMoji, qui a déjà des couleurs en dur) — nécessaire pour Lucide/Tabler si utilisés un jour, sans effet sur Material (déjà sans `currentColor`).

`_covers.py::place_on_canvas` et `07b_icons_page.py` n'ont pas changé : ils ne manipulent que des PNG déjà composés, jamais les identifiants.

## Licence

Material Symbols est sous licence **Apache 2.0** — pas d'attribution visible requise (contrairement à OpenMoji CC BY-SA 4.0 ou Font Awesome Free CC BY 4.0, non retenu ici). Une mention factuelle a été ajoutée dans `README.md` par cohérence avec les autres prérequis listés, sans bloc de licence obligatoire.

## Limites

- Même limite qu'en 0001 : pas de test sur Lunii physique, jugement basé sur un rendu numérique fidèle au pipeline réel.
- Le remplacement `material:museum` introduit une **dépendance réseau vers un nouveau dépôt tiers** (`google/material-design-icons`) en plus d'OpenMoji — accepté ici pour un seul code, à réévaluer si le nombre de dépendances externes venait à croître.
- Le mélange de deux styles graphiques (OpenMoji au trait, Material en silhouette pleine) sur un seul écran du pack (musée d'Orsay) n'a pas été jugé problématique au rendu — un seul remplacement isolé ne crée pas d'incohérence visuelle perceptible en feuilletant les catégories, mais ce jugement mériterait d'être révisé si d'autres remplacements de ce type s'accumulaient à l'avenir.
