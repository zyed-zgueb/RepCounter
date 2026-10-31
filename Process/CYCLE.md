# Cycle en cours

Ce fichier est réécrit à chaque cycle (l'historique reste dans git). Vincent valide le cadrage
avant tout code.

## Cycle 1 : repartir sur une base qui compile et qui suit les décisions

**Statut** : proposé, à valider par Vincent.

**Objectif (vérifiable)** : la CI est verte sur `main`, et le plan applique la règle des jours
validée (`Science/METHODE-JOURS.md`), vérifié sur l'iPhone par la recette.

**Dedans**
- Faire passer la CI : corriger tout ce que Xcode refuse dans le code actuel (jamais compilé par
  un agent jusqu'ici).
- Appliquer `Science/METHODE-JOURS.md` : N choisi par la personne (l'habitude reste le défaut),
  repos la veille du test, mention pour N = 1, repos placé par l'app jamais compté comme manqué.
  Retirer la réinitialisation des jours de 72c3383 / ef25a42, que cette règle remplace.
- Mettre `Simulation/plan.py` en phase avec le code.

**Dehors (backlog)**
- Audit complet des règles de planification (`Science/AUDIT-PLANIFICATION.md`, provisoire :
  textes intégraux bloqués par le réseau).
- Tout nouvel écran, nouvelle astuce, nouveau graphique.

**Questions à Vincent**
1. **La CI sur un Mac de GitHub** (runner macOS, minutes facturées au-delà du quota gratuit
   pour un dépôt privé). *Recommandé : oui*, c'est ce qui vous retire le rôle de compilateur.
   Sinon : vous compilez vous-même, mais une fois par lot seulement.
2. **Sources scientifiques bloquées** : la session Science ne pouvait pas lire les textes
   intégraux (PubMed Central, Europe PMC, jssm.org, csep.ca). *Recommandé : ouvrir ces domaines
   dans le réseau de l'environnement* ; sinon, déposer les PDF dans `Science/sources/`.
3. **Ce cycle est-il le bon premier pas ?** *Recommandé : oui* ; l'alternative serait de
   d'abord valider le comptage sur de nouveaux enregistrements réels (4 seulement à ce jour).

## Backlog
- Audit complet de la planification, une fois les textes intégraux accessibles.
- Nouveaux enregistrements réels du compteur (Développé épaules non simulé).
- Fiche App Store (tickets `lancement`, session marketing du 28/10).
