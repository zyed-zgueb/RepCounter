# Cycle en cours

Ce fichier est réécrit à chaque cycle (l'historique reste dans git). Vincent valide le cadrage
avant tout code.

## Cycle 1 : une base qui compile, et un coach qui décide des jours

**Statut** : validé par Vincent le 31/10, en construction.

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

**Questions à Vincent**
1. ~~La CI sur un Mac de GitHub~~ : **oui** (Vincent, 31/10). Elle est verte : le code actuel
   compile (runs 1 et 2 de `.github/workflows/build.yml`).
2. **Sources scientifiques bloquées** (PubMed Central, Europe PMC, jssm.org, csep.ca).
   *Recommandé : ouvrir ces domaines dans le réseau de l'environnement* ; sinon, déposer les PDF
   dans `Science/sources/`.
3. **Le cadrage ci-dessus vous va-t-il ?** Un « oui » suffit pour lancer le code.

## Backlog
- Rafraîchir la ligne du jour au passage de minuit, app ouverte (aucun observateur aujourd'hui ;
  relecture du cycle 1).
- Audit complet de la planification, une fois les textes intégraux accessibles.
- Nouveaux enregistrements réels du compteur (Développé épaules non simulé).
- Fiche App Store (tickets `lancement`, session marketing du 28/10).
