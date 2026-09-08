# 0003 — Ne trimmer le silence qu'aux bords externes de l'histoire fusionnée

**Statut** : Accepté
**Date** : 2026-09-08
**Issue** : [#4](https://github.com/mightywhitysocks/spotify-to-lunii-pack/issues/4)

## Contexte

`_build/scripts/02_merge.ps1` fusionne les chapitres d'une histoire en un seul MP3. Le filtre `silenceremove` qui rogne le silence en bord de chapitre (`$trim`) était appliqué **identiquement à chaque chapitre**, quelle que soit sa position dans la boucle de construction du graphe `filter_complex`. Conséquence : les bords **internes** (fin de chapitre N / début de chapitre N+1, qui se retrouvent au milieu de l'histoire fusionnée) étaient rognés exactement comme les vrais bords externes — seuil `-50dB`, fenêtre `0.05s` (en dur, absente de la config), mode de détection `rms` implicite. Une consonne douce ou une syllabe en attaque faible passait sous ce seuil agressif et disparaissait.

Il y a déjà 0.8s de silence numérique pur (`anullsrc`, `merge.gap`) injecté entre deux chapitres dans le graphe `filter_complex` — donc **aucun risque de clic** à la jonction même sans trim ni crossfade. Le bug n'était donc pas dans la présence de ce gap, mais dans le fait de trimmer des bords qui ne sont pas de vrais bords externes.

## Décision : filtre conditionné par position, un seul appel ffmpeg conservé

Un seul appel ffmpeg est conservé (même pattern `filter_complex` + `concat`, pas de fichier intermédiaire, pas de crossfade). Une approche à deux passes (concat brut → fichier intermédiaire → trim externe) aurait été objectivement inférieure : le bug n'est pas dans l'architecture mais dans le fait d'appliquer le même filtre à tous les inputs indépendamment de leur position ; un ré-encodage intermédiaire ajouterait une génération de compression MP3 supplémentaire (perte de qualité) pour un gain nul, puisque `filter_complex` permet déjà de brancher un filtre différent sur chaque label d'entrée avant le `concat` final.

Le filtre branché sur `[i:a]` est désormais conditionné à la position du chapitre `i` parmi `n` :
- chapitre unique (`n=1`) : trim des deux bords (les deux sont externes)
- premier chapitre (`n>1`) : trim du **début** seulement (sa fin touche un `gap`, jamais un vrai bord)
- dernier chapitre (`n>1`) : trim de la **fin** seulement
- chapitre intermédiaire : **aucun trim**, juste `aresample`/`aformat`

## Recherche documentaire

Une première version de ce travail reprenait l'intuition de l'issue (`detection=peak` "plus prudent") en s'alignant sur `03_titles.py::cut_clip()`, qui utilise déjà `peak`. Vérification faite avant de trancher :

- La **documentation FFmpeg officielle** (`ffmpeg-filters.html#silenceremove`) dit : *"Should the exact signal be taken in case of `peak` or an RMS one in case of `rms`. Default is `rms` which is mostly smoother."* — `rms` est le défaut, décrit comme plus lisse, pas `peak`.
- Une source académique (Aalto University, wiki VAD) confirme que les **consonnes fricatives douces (f, s, ch — exactement le cas cité par l'issue) sont le cas le plus difficile pour toute détection par seuil d'énergie**, `rms` ou `peak` confondus. Aucun des deux modes ne résout structurellement ce problème.
- Les sources ne convergent pas sur lequel des deux modes évite le mieux de couper une syllabe : `peak` réagit à un seul échantillon fort (moins susceptible de rater un pic isolé), `rms` moyenne l'énergie sur la fenêtre (plus "smooth" mais peut diluer une syllabe brève sous le seuil moyen).

**Décision** : ne pas forcer `detection=peak` par défaut sans preuve. `merge.trim_detection` reste à `"rms"` (comportement ffmpeg actuel, inchangé), exposé comme paramètre pour que l'utilisateur teste les deux modes à l'oreille sur ses propres fichiers.

Une pratique distincte et bien établie a en revanche été confirmée : le **"guard band"** — ne jamais couper exactement à la frontière détectée du silence, mais laisser une marge de sécurité (padding) après la coupe. C'est précisément ce que fait déjà `03_titles.py::cut_clip()` avec `apad=pad_dur=0.14`, jusqu'ici pas repris dans `02_merge.ps1`. Cette technique est reprise ici (`merge.trim_pad`).

Écosystème Lunii (`studio-pack-generator`, `lunii-studio`, `story-studio`) : aucun de ces outils ne gère la fusion multi-chapitres en histoire ni ce problème de jonction — pas de solution de référence externe à réutiliser.

## `03_titles.py` examiné — pas affecté par le bug

Recherche exhaustive dans le repo (`grep silenceremove`) : seuls 2 fichiers utilisent ce filtre — `02_merge.ps1` (corrigé ici) et `03_titles.py::cut_clip()`. Ce dernier a été relu intégralement pour vérifier s'il porte le même bug structurel ou un risque analogue.

**`03_titles.py` n'a pas le bug de #4** : il n'y a pas de notion de "jonction interne" dans son cas d'usage — `cut_clip()` extrait et nettoie un **seul segment continu** (l'annonce du titre, localisée par whisper dans le chapitre 1 source), jamais plusieurs segments à raccorder. Les deux bords qu'il trimme sont donc toujours de vrais bords de coupe.

Il partage le même risque *générique* de `silenceremove` et le mitige déjà avec trois mécanismes absents de `02_merge.ps1` :
1. une marge généreuse avant le trim (`vad_l`/`vad_r`, 0.40s/0.28s autour du span détecté par whisper) ;
2. le guard band `apad=pad_dur=0.14` déjà cité ci-dessus ;
3. une **revérification a posteriori par re-transcription whisper** : le clip résultant est retranscrit, et si le dernier mot du titre n'y apparaît pas, la ligne est flaguée `titre?`/`A_VERIFIER` pour vérification manuelle — un filet de sécurité que `02_merge.ps1` n'a pas et n'aura pas ici (ce script est du ffmpeg pur, sans dépendance whisper ; ajouter une telle vérification serait un changement d'architecture disproportionné pour ce fix — à envisager séparément si le simple resserrement des bords externes s'avère insuffisant à l'usage).

`03_titles.py` n'a donc pas été modifié dans sa logique.

## Homogénéisation du vocabulaire de configuration

`merge.*` avait des clés nommées (`trim_silence_db`), `titles.*` avait les mêmes réglages câblés en dur dans `cut_clip()` (`-48dB`/`0.18s` en tête, `-45dB`/`0.08s` en fin, `apad=0.14`, `detection=peak`), invisibles dans `project.schema.md`. Les deux scripts ne peuvent pas partager de **code** (PowerShell vs Python, cas d'usage différents) sans un refactor disproportionné pour ce fix — mais le **vocabulaire de configuration** peut et doit être homogène :

```
<scope>.trim_head_db / trim_head_window   -- bord de tête
<scope>.trim_tail_db / trim_tail_window   -- bord de fin
<scope>.trim_detection                    -- "peak" | "rms"
<scope>.trim_pad                          -- guard band après coupe
```

`03_titles.py::cut_clip()` lit désormais ces 6 valeurs depuis `CONFIG["titles"]` au lieu de les avoir en dur — **mêmes valeurs numériques qu'avant, vérifié par comparaison de chaîne caractère par caractère** (`-48dB`/`0.18`/`-45dB`/`0.08`/`peak`/`0.14`), donc zéro changement de comportement sur un script déjà éprouvé.

## Réglages retenus

| Clé | Avant | Après |
|---|---|---|
| `merge.trim_head_db` / `trim_head_window` | `trim_silence_db=-50`, fenêtre 0.05 en dur | `-45` / `0.3` |
| `merge.trim_tail_db` / `trim_tail_window` | idem | `-45` / `0.3` |
| `merge.trim_detection` | `rms` implicite | `"rms"` explicite |
| `merge.trim_pad` | absent | `0.1` |
| `titles.trim_head_db` / `trim_head_window` | `-48dB`/`0.18` en dur | `-48` / `0.18` (extrait, inchangé) |
| `titles.trim_tail_db` / `trim_tail_window` | `-45dB`/`0.08` en dur | `-45` / `0.08` (extrait, inchangé) |
| `titles.trim_detection` | `peak` en dur | `"peak"` (extrait, inchangé) |
| `titles.trim_pad` | `0.14` en dur | `0.14` (extrait, inchangé) |

`lead`/`tail`/`gap` de `merge.*` restent inchangés (0.3/0.6/0.8) — l'issue liste le gap comme question ouverte non tranchée ("faut-il vraiment 0.8s entre chapitres"), pas comme partie confirmée du bug ; hors périmètre de ce fix.

## Repro documentée

40 des 45 histoires du pack Timoté ont exactement 2 chapitres, donc une seule jonction interne chacune (aucune histoire à 3+ chapitres). Candidates de vérification à l'oreille, nommées explicitement :
- « Timoté et sa tétine » (chapitres 052/053)
- « Timoté et son doudou » (chapitres 036/037)

## Limites

Aucun test réel possible dans ce sandbox : pas de `pwsh` disponible sur Linux, aucun fichier audio réel committé (`*.mp3` gitignorés). La correction de `02_merge.ps1` n'a pu être vérifiée que par lecture attentive et reconstruction manuelle du filtre ffmpeg généré pour les cas à 1 et 2 chapitres, pas par une écoute réelle. Le changement dans `03_titles.py` est une extraction de constantes vérifiée par comparaison de chaîne exacte (risque de régression minimal).

## Checklist de déploiement (à exécuter par l'utilisateur)

1. Forcer le rebuild des histoires déjà fusionnées avec l'ancien comportement — le cache RECONCILE de `02_merge.ps1` ne se base que sur "clé + fichier encore présent", pas sur un hash de contenu :
   ```powershell
   .\02_merge.ps1 -Rebuild
   ```
   (purge aussi le dossier de backups loudness, donc `04b_normalize.ps1` devra retraiter tout le tree.)
2. Vérifier dans la sortie console que `merged` correspond au nombre total d'histoires et `reused = 0` sur ce run.
3. Réécouter en priorité les histoires nommées ci-dessus, en se concentrant sur :
   - la toute première syllabe du chapitre 2, juste après le gap de 0.8s (point de coupe signalé par l'issue) ;
   - l'absence de nouveau clic ou de silence anormalement long à la même jonction ;
   - le tout début et la toute fin de l'histoire (toujours trimmés), qui doivent rester propres.
4. Transférer sur une vraie Lunii et réécouter en conditions réelles, comme demandé par le livrable de l'issue.
5. Si des coupes sont encore audibles avec `trim_detection="rms"`, tester `"peak"` en alternative (`merge.trim_detection`) et comparer à l'oreille.
6. Comparer optionnellement `_build/audio_report.csv` avant/après sur quelques histoires pour confirmer que le LUFS mesuré n'a pas significativement bougé.
