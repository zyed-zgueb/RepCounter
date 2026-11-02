# Nouveautés

Ce qui a changé à l'écran, version après version, en mots de l'utilisateur, avec un extrait
avant / après (`Design/Nouveautes/<date>/`). Les plus récentes en haut. Le Builder ajoute une
ligne à chaque changement visible, au moment où il le fait, et montre ces paires à Vincent à la
livraison : on juge plus facilement un changement qu'un écran entier.

Page pour Vincent (la même adresse à chaque livraison, nouvelle version en tête) :
https://claude.ai/artifact/4BvJtn4xJ2R8gYSd8CT6HP, publiée depuis `Design/Nouveautes/index.html`.
Sous chaque changement, Vincent dit « Ça me va » ou « À revoir » et peut commenter ; ses avis
sont enregistrés avec la page (collection `avis`, identifiant `<date>-<extrait>`). Le Builder
les lit au début de chaque cycle et à chaque livraison ; un « À revoir » est un défaut du cycle.

Les captures complètes de chaque version sont archivées par la CI sur la branche `ci-captures`
(un dossier par version : date et commit ; `latest/` pour la dernière).

## 02/11 (suite) : tes 3 « À revoir » du cycle 4

| # | Écran | Ce qui change | Extraits |
|---|---|---|---|
| 30 | Série | Le chiffre décompte (« 6 à faire sur 23 »), « +2 » au-delà ; vidéo | `2026-11-02b/30-decompte`, `tunnel.mp4` |
| 31 | Historique, Journal | « 0 » au lieu des pointillés | `2026-11-02b/31-journal` |
| 32 | Coaching, Chemin | Pictos et légende ; tests colorés face à la ligne théorique | `2026-11-02b/32-chemin` |

## 02/11 : cycle 4, Coaching et Historique allégés

| # | Écran | Ce qui change | Extraits |
|---|---|---|---|
| — | Série, repos | Vidéos du tunnel et de la fin du repos | `2026-11-02/tunnel.mp4`, `fin-du-repos.mp4` |
| 27 | Coaching, Chemin | Plus de losanges ni de drapeau ; « aujourd'hui », « objectif 40 » | `2026-11-02/27-chemin` |
| 28 | Historique, 12 semaines | Plus de pourcentage trompeur sur la semaine en cours | `2026-11-02/28-semaines` |
| 29 | Historique, Journal | Pointillés visibles | `2026-11-02/29-journal` |
| — | Coaching, Historique | Textes lus à 15 ou 17 ; abréviations en mots ; « En savoir plus sur les phases » | (sans extrait) |

## 01/11 (nuit, fin) : tes 2 derniers « À revoir » du cycle 3

| # | Écran | Ce qui change | Extraits |
|---|---|---|---|
| 25 | Fin de séance | Chaque série face à sa cible (✓ ou −1) ; pourcentage sur les cibles affichées | `2026-11-01e/25-series` |
| 26 | Historique | Plus de losanges sur la courbe | `2026-11-01e/26-courbe` |

## 01/11 (nuit, suite) : tes 4 « À revoir » du cycle 3

| # | Écran | Ce qui change | Extraits |
|---|---|---|---|
| 21 | Série | Tunnel en perspective (tuiles ombrées, bords qui fuient vers le centre) | `2026-11-01d/21-tunnel` |
| 22 | Repos | Une lumière par seconde ; 3, 2, 1 au son | `2026-11-01d/22-repos` |
| 23 | Fin de séance | Part de la cible faite (« Presque atteinte : 97 % ») | `2026-11-01d/23-fin` |
| 24 | Historique | Ligne fine du record, chiffre en petit | `2026-11-01d/24-record` |

## 01/11 (nuit) : cycle 3, pendant et après l'effort

| # | Écran | Ce qui change | Extraits |
|---|---|---|---|
| 18 | Série | Tunnel de comptage (un anneau de 10 par dizaine, cible entière visible), « sur 23 », « Série 2 sur 3 » ; plus de chronomètre ni de rangée des séries | `2026-11-01c/18-serie` (nouveau) |
| 19 | Repos | Compte à rebours, « Prêt » à zéro ; série suivante et sa cible en grand | `2026-11-01c/19-repos` (nouveau) |
| 20 | Fin de séance | Trois blocs (cible, la suite, le coach) ; détail à part ; « Terminé » | `2026-11-01c/20-fin` (nouveau) |
| 13 | Coaching, Aujourd'hui | « effort normal » et jauge à 3 crans ; plus de puce | `2026-11-01c/13-effort` |
| 14 | Coaching, jour de test | Sans pictogrammes ; chiffre à battre en grand ; « En savoir plus » | `2026-11-01c/14-jour-de-test` |
| 15 | Historique, 12 semaines | Plus d'étoiles ; « record : N » de toujours ; « reps par semaine » | `2026-11-01c/15-record` |
| 16 | Historique, Journal | « total » devient « reps » | `2026-11-01c/16-journal` |
| 17 | Cadran | Plus de « caméra » ni de point seul sous la fatigue | `2026-11-01c/17-fatigue` |

## 01/11 (soir) : corrections de la recette du cycle 2

| # | Écran | Ce qui change | Extraits |
|---|---|---|---|
| 9 | Coaching, Aujourd'hui | Séance terminée sous la cible : « fait · cible non atteinte », prochaine séance et ses cibles | `2026-11-01b/09-seance-faite` |
| 10 | Coaching, jour de test | « Série max », dernier résultat, et pourquoi le test est attendu | `2026-11-01b/10-jour-de-test` |
| 11 | Cadran, repos conseillé | La raison ne commence plus par un point isolé | `2026-11-01b/11-repos` |
| 12 | Coaching, grand texte | Plus rien de coupé ; la frise dit « Cette semaine : progrès » | `2026-11-01b/12-grand-texte-plan` |

## 01/11 : revue de design sur les premières captures

| # | Écran | Ce qui change | Extraits |
|---|---|---|---|
| 1 | Coaching, carte Aujourd'hui | « soutenue » devient « intensité soutenue » | `01-intensite` |
| 2 | Coaching, Chemin | Le repère d'aujourd'hui ne masque plus « pompes d'affilée » | `02-chemin` |
| 3 | Historique, filtre | « Σ » devient « Tous » | `03-tous` |
| 4 | Historique, 12 semaines | « cette semaine » n'est plus coupé | `04-cette-semaine` |
| 5 | Historique, 12 semaines | Plus d'étoiles empilées sur les semaines de test | `05-etoiles` |
| 6 | Historique, 12 semaines | « reps / sem. » devient « répétitions par semaine » | `06-repetitions` |
| 7 | Historique, Journal | « Σ » devient « total », « auj. » devient la date du jour | `07-journal` |
| 8 | Cadran | « Fatigue ? » n'est plus coupé ; « CAM 3D » devient « caméra » | `08-fatigue` |

Avant le 01/11, il n'y avait pas de captures : les changements du cycle 2 (carte « Ton plan »,
5 tailles de texte, cartes aérées) n'ont pas d'image « avant ».
