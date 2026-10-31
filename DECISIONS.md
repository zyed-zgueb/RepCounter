# Journal des décisions

Une ligne par décision qui compte : on ne la rediscute pas sans fait nouveau (CLAUDE.md).
Les plus récentes en haut. « V » = décidé par Vincent ; « B » = décidé par le Builder.

| Date | Décision | Par | Raison / source |
|---|---|---|---|
| 2026-10-31 | Nouvelle organisation : Vincent, un Builder, un Reviewer ponctuel ; règles dans `CLAUDE.md`. Les sessions Produit, Développement, Relecture, Science du sport et Contrôle du process sont closes. | V | Cinq sessions convergeaient mal, consommaient beaucoup et faisaient de Vincent le relais et le compilateur. |
| 2026-10-31 | Les documents de méthode (`Science/`) sont ramenés sur `main` depuis `science/audit-planification`. | V | Le code citait `Science/METHODE-TEST.md`, absent de `main`. |
| 2026-10-31 | Application du coach quotidien : une semaine de progression est refaite sous 2 séances (1 seule exigée la semaine où le plan commence en cours de semaine) ; le jour de test est le lundi après la semaine allégée ; les 2 tests de calibrage du bloc 1 sont proposés chaque jour de la 1re semaine ; après le test, une séance chaque jour jusqu'au bloc suivant ; le « prévu » des barres = les cibles des séances faites. | B | Plus de jours prévus ni de nombre de séances attendu. Cycle 1. |
| 2026-10-31 | CI sur un Mac de GitHub (`macos-26`) : compilation iOS et simulation du compteur à chaque push. Branche `science/audit-planification` supprimée (contenu ramené dans `Science/`). | V | Retirer à Vincent le rôle de compilateur. |
| 2026-10-31 | Règles du coach quotidien : séance par défaut ; repos conseillé seulement la veille du test, en fatigue persistante, après une séance « Très difficile », ou au-delà de 20 séries sur 7 jours ; un repos reste une proposition. | B | `Science/METHODE-JOURS.md`, règles 1 à 8. |
| 2026-10-31 | **Plus de réglage de jours.** Le coach suppose qu'on peut s'entraîner tous les jours et propose chaque jour une séance ou un repos. Remplace « N jours au plus » (même jour) et la réinitialisation des jours (72c3383). | V | Les pompes sont courtes et se glissent n'importe quand dans une journée. **Pas encore dans le code** (`Process/CYCLE.md`). |
| 2026-10-31 | ~~Jours d'entraînement : N jours par semaine au plus.~~ Remplacée par la décision ci-dessus. | V | — |
| 2026-10-30 | Test annoncé : jour de test visible, la personne lance elle-même la série max ; max relevé = répétitions faites. | V | `Science/METHODE-TEST.md` ; commits 31c8351, 16ada77. |
| 2026-10-30 | Cas limites du test, de la reprise, du journal, des verdicts, de l'objectif atteint. | V | Commit 609d333. |
| 2026-10-30 | Tendances en couleur de texte ; vert du test seulement sur un gain réel. | V | Skill reps-ux § 5 ; Hopkins. |
| 2026-10-30 | Conformité Apple : feuilles natives, SF Symbols, zones de 44 pt, Dynamic Type, Swift Charts, TipKit. | V | Skill reps-ux § 11. |
| 2026-10-30 | Les thèmes habillent le compteur seulement ; le reste suit le thème système. | V | README, Thèmes. |
| 2026-10-29 | Prescription d'après l'ACSM 2026 ; plan en blocs 3 + 1 + test. | V | Commits ff03d36, 1919836. |
| 2026-10-29 | Organisation des écrans par fréquence de lecture, une responsabilité par écran. | V | Skill reps-ux § 1–2. |
