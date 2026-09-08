# 0001 — Évaluation d'OpenMoji "black" pour les icônes enfant (2-4 ans)

**Statut** : Accepté
**Date** : 2026-09-08
**Issue** : [#2](https://github.com/mightywhitysocks/spotify-to-lunii-pack/issues/2)
**Complété par** : [0002-icones-ui-multi-bibliotheques.md](0002-icones-ui-multi-bibliotheques.md) (la ligne `1F3DB` du tableau ci-dessous est supersédée par cette décision ultérieure ; le reste de ce document reste valide tel quel)

## Contexte

Le pipeline (`_build/scripts/07_icons.py` + `_covers.py::place_on_canvas`) génère les écrans catégorie/histoire (320×240) à partir du set OpenMoji **black** (SVG au trait), rendu en négatif (`ffmpeg negate`) : pictogramme blanc sur fond quasi-noir `#0A0D12`. Ce choix, jamais évalué, était présumé risqué pour la cible du produit (enfant de 2-4 ans, écran basse résolution) au motif que le trait fin OpenMoji pourrait devenir illisible une fois réduit à 232px.

Deux faits établis en amont cadrent l'évaluation :
- **La composition blanc-sur-noir n'est pas un choix esthétique du projet, c'est une contrainte matérielle** : la documentation de `studio-pack-generator` (le générateur utilisé par ce pipeline) est explicite — l'écran Lunii ne rend que le blanc, d'où la pratique de partir d'un fond noir avec le dessin en blanc. Toute alternative testée devait donc rester dans ce même registre (silhouette blanche sur fond sombre), sans quoi elle serait invisible sur le matériel réel.
- **Aucune littérature scientifique dédiée à la tranche 2-4 ans sur "trait vs silhouette" n'a été trouvée.** Le seul principe généraliste sourcé disponible (UX Movement, *"Solid vs. Outline Icons: Which Are Faster to Recognize?"*) est : pour des icônes en contour, un espacement interne large réduit le bruit visuel et facilite la reconnaissance ; un espacement fin l'augmente. Ce principe a servi de grille de lecture, pas de caution scientifique enfant qui n'existe pas.

## Méthode

Faute d'accès à une Lunii physique dans l'environnement d'exécution, l'évaluation a été faite sur un **rendu numérique fidèle au pipeline réel** : réutilisation directe de `07_icons.py::get_png`/`CAT_ICON`/`STORY_ICON` et de `_covers.py::place_on_canvas` (même `ffmpeg`, mêmes valeurs `image.{w,h,fit,canvas}` de `project.json`), pour produire les 50 icônes réellement utilisées (9 catégories + 44 histoires, 4 codes partagés → 50 codes uniques, un de plus que l'estimation "~54" de l'issue une fois dédupliqués) en 320×240, puis des planches de contact lues visuellement.

Trois variantes ont été comparées sur le même jeu de 50 codes :
1. **OpenMoji black** tel quel (référence actuelle).
2. **OpenMoji black + épaississement** du trait (`imagemagick -morphology Dilate:2 Disk`), pour tester l'hypothèse "trait trop fin".
3. **Fluent Emoji "High Contrast"** (Microsoft, licence MIT, silhouettes pleines conçues pour l'accessibilité/fort contraste) — candidat identifié en recherche documentaire, non envisagé par l'issue initiale.

## Résultats observés

**Couverture** : OpenMoji black 50/50. Fluent High Contrast 46/50 (manquants : `1F30D` planète, `1F476` bébé, `1F4AA` biceps, `1F6CC` lit — noms de dossier introuvables sous les conventions CLDR usuelles, non résolus).

**OpenMoji black, à la résolution et au contraste réels** : contrairement à l'hypothèse de départ, le rendu est **globalement très lisible**. Le contraste blanc pur / noir quasi-pur donne des contours nets ; aucune "disparition" massive de trait n'a été observée sur les icônes concrètes (maison, gâteau, vélo, chien, ours, pansement, dent, château, etc.). La faiblesse réelle du set n'est donc **pas perceptuelle mais sémantique** : quelques codes reposent sur une métaphore ou une convention adulte que l'enfant ne peut pas décoder sans apprentissage préalable.

**OpenMoji black + épaississement** : effet **mixte et imprévisible**, à rejeter comme traitement uniforme. Les icônes simples à traits espacés (vélo, ours, pansement) restent correctes, mais les icônes à détails rapprochés (globe, gâteau à étages, lunettes, ballon de foot, visage du singe) deviennent des masses confuses où les hachures/motifs internes fusionnent. Une dilatation appliquée automatiquement à 50 icônes hétérogènes dégraderait plus d'icônes qu'elle n'en améliorerait.

**Fluent Emoji High Contrast** : silhouettes pleines effectivement un peu plus "salientes" que le contour OpenMoji sur certains cas (croix de l'hôpital, horloge de l'école, ballon de foot à pentagones, `1F5FC` rendu en tour Eiffel reconnaissable là où OpenMoji ne dessine qu'un poteau avec antenne). Mais le gain est marginal sur l'ensemble du jeu, ne règle **aucun** des problèmes sémantiques identifiés (le singe "bêtises" reste une métaphore adulte même en silhouette pleine), et migrer demanderait d'ajouter au pipeline une table de correspondance code Unicode → nom de dossier Fluent (actuellement `07_icons.py` utilise le code hex directement dans l'URL OpenMoji, sans mapping) pour une couverture qui resterait incomplète (46/50).

## Décision

**Approche hybride ciblée** : conserver OpenMoji "black" comme set (couverture 100 %, lisibilité perceptuelle confirmée par l'observation directe, pipeline et licence déjà en place), et ne remplacer que les codes dont le problème est démontré et pour lesquels un remplacement clairement meilleur existe — pas de changement de set, pas de post-traitement systématique.

Les deux options rejetées (épaississement systématique, migration vers Fluent) le sont sur preuve, pas sur hypothèse : la première dégrade objectivement des icônes correctes, la seconde ne corrige pas le vrai défaut identifié pour un coût de migration non négligeable.

## Icônes à remplacer

| Code | Usage | Problème observé | Remplacement | Code proposé |
|---|---|---|---|---|
| `1F3AC` (clapper board) | histoire « va au spectacle » | Le clap de cinéma évoque un tournage, pas un spectacle vivant (théâtre/cirque) — lien indécodable pour un enfant | Masques de théâtre | `1F3AD` (performing arts) |
| `1F648` (see-no-evil monkey) | histoire « fait des bêtises » | Métaphore adulte ("ne rien voir" → faute) sans rapport visuel avec la bêtise ; un enfant de 2-4 ans ne peut pas faire ce lien | Visage souriant à cornes, immédiatement lisible comme "coquin/vilain" | `1F608` (smiling face with horns) |

Les deux remplacements ont été vérifiés existants dans OpenMoji black (HTTP 200) et rendus avec le même pipeline avant d'être proposés.

## Cas examinés et non modifiés

| Code | Usage | Constat | Décision |
|---|---|---|---|
| `1F3DB` (classical building) | « musée d'Orsay » | Bâtiment classique générique — mais c'est la convention de facto utilisée par la plupart des sets d'emoji pour "musée", faute d'un glyphe Unicode dédié | Conservé : pas de meilleure alternative Unicode disponible |
| `1F5BC` (framed picture) | « Louvre » | Tableau encadré générique — même logique, convention standard pour "art/musée" | Conservé, même raison |
| `1F5FC` (Tokyo tower) | « visite Paris » | Le glyphe Unicode réel n'a pas de "tour Eiffel" dédiée ; le rendu OpenMoji noir (poteau + antenne) est peu reconnaissable comme une tour, alors que d'autres sets (Fluent) dessinent ce même code en silhouette de tour Eiffel | Conservé : limite du **set** OpenMoji sur ce glyphe précis, pas du choix de code — à surveiller si OpenMoji redessine ce glyphe dans une future version |
| `1F9B7` (tooth) | « et la petite souris » | Repose sur la convention culturelle française (dent → petite souris), pas sur la forme du pictogramme lui-même | Conservé : c'est un apprentissage culturel attendu, pas un défaut de lisibilité |
| `1FA79` (adhesive bandage) | catégorie « Corps et santé » | Symbole conventionnel de santé, bien identifiable | Conservé |

## Licence

OpenMoji est sous licence **CC BY-SA 4.0**. Le texte d'attribution officiel suggéré par le projet — *"All emojis designed by OpenMoji – the open-source emoji and icon project. License: CC BY-SA 4.0"* — a été ajouté dans `README.md`, absent jusqu'ici.

**Point à surveiller** : la clause *ShareAlike* de CC BY-SA 4.0 s'applique à tout dérivé distribué. Le pipeline ne pratique aujourd'hui aucun post-traitement des glyphes (cette évaluation rejette justement l'épaississement), donc le risque est nul en l'état ; il redeviendrait pertinent si un post-traitement des glyphes était introduit plus tard.

## Limites de l'évaluation

- **Pas de test sur Lunii physique** : l'évaluation s'appuie sur un rendu numérique fidèle au pipeline (mêmes fonctions, même résolution, même négatif), pas sur une observation de l'écran réel de l'appareil. C'est la limite principale à garder en tête avant de considérer cette décision comme définitive.
- **Pas de test utilisateur avec des enfants de 2-4 ans** : le jugement de lisibilité repose sur des critères objectifs (silhouette, détails internes, distance métaphorique) et un principe UX généraliste, pas sur une observation d'enfants réels face à l'écran.

## Point annexe (hors scope, à traiter séparément)

Deux fragilités de robustesse du pipeline ont été identifiées en cours d'analyse, sans rapport avec le choix du set d'icônes :
1. Le cache `_build/tools/openmoji/<code>.png` n'est jamais invalidé si `icons.set` change (`07_icons.py::get_png`) — changer de set sans vider le cache réutiliserait silencieusement les anciens PNG.
2. Le "fallback texte" annoncé pour une icône manquante (`OK n images / m manquantes (gardent le texte)`) ne fonctionne qu'en rebuild incrémental : en cold start, `05_run_spg.ps1` désactive globalement la génération d'image texte de secours dès que `icons.mode="emoji"`, donc une icône manquante au premier build se retrouve sans image du tout.

Recommandation : ouvrir une issue dédiée à ces deux points plutôt que de les traiter ici — ce sont des bugs de pipeline, pas une décision UX.

**Résolu** par [#30](https://github.com/mightywhitysocks/spotify-to-lunii-pack/issues/30) : (1) cache OpenMoji namespacé par set (`_build/tools/openmoji/<set>/`) ; (2) `07_icons.py` écrit `work/icons_report.json` et `05_run_spg.ps1` ne passe `--skip-image-item-gen` que si la couverture est à 100 %, laissant sinon SPG rendre un écran texte de secours pour chaque icône manquante.
