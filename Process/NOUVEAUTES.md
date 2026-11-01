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
