# Cycle en cours

Ce fichier est réécrit à chaque cycle (l'historique reste dans git). Vincent valide le cadrage
avant tout code.

## Cycle 1 : une base qui compile, et un coach qui décide des jours

**Statut** : livré le 31/10, en recette (`Process/RECETTE-CYCLE-1.md`).

**Objectif (vérifiable)** : la CI est verte sur `main`, et sur l'iPhone le Coaching n'a plus
aucun réglage de jours : chaque jour il propose une séance ou un repos, selon
`Science/METHODE-JOURS.md`.

**Dedans**
- ~~Faire passer la CI~~ : fait, le code actuel compile.
- Retirer les jours : rangée et feuille des jours, « Jours réinitialisés », jours enregistrés,
  `perWeek`, « semaine faite 2/4 », séances manquées (journal et historique).
- Ajouter la décision du jour (règles 3 à 6) : « séance » ou « repos conseillé » avec sa raison
  en quelques mots, sur la ligne sous le cadran et dans la carte Aujourd'hui du Coaching.
- Jour de test sans jour fixe (règle 7).
- Mettre `Simulation/plan.py` en phase, et le skill reps-ux et le (i) « Les jours » à jour.

**Dehors (backlog)**
- Audit complet de la planification (`Science/AUDIT-PLANIFICATION.md`, provisoire).
- Tout nouvel écran, nouvelle astuce, nouveau graphique.

**Ce que Vincent vivra dans l'app** (validé le 31/10) : plus aucun réglage de jours ; chaque
jour, l'app lui propose une séance, ou lui conseille un repos en disant pourquoi.

**Questions d'utilisateur final** : aucune en attente.

## Backlog
- Rafraîchir la ligne du jour au passage de minuit, app ouverte (aucun observateur aujourd'hui ;
  relecture du cycle 1).
- Audit complet de la planification. Les textes intégraux restent bloqués par le réseau de
  l'environnement : on continue avec les résumés (décision du Builder, 31/10).
- Nouveaux enregistrements réels du compteur (Développé épaules non simulé).
- Fiche App Store (tickets `lancement`, session marketing du 28/10).
