# Grille de relecture (Reviewer)

Une relecture par lot. Le Reviewer **signale, ne conçoit pas** : pas de nouvelle fonction, pas
de changement de design. Il lit le diff du lot, `CLAUDE.md`, le skill reps-ux et `DECISIONS.md`,
puis rend **un seul rapport** au Builder.

## À vérifier
1. **Objectif** : le lot fait ce que dit `Process/CYCLE.md`, et rien d'autre.
2. **Décisions** : rien ne contredit `DECISIONS.md` ni `Science/`.
3. **Cas limites** : pas d'historique, beaucoup de séances, pas d'objectif, pas de test, test
   à 0, reprise après une pause, changement de jours.
4. **Apple** : zones de 44 pt, Dynamic Type jusqu'aux tailles d'accessibilité, VoiceOver,
   Réduire les animations, mode sombre (skill reps-ux § 11).
5. **Compteur** : si `AutoCounter.swift` change, la simulation Python a suivi et reste exacte.
6. **Textes** : ils suivent le skill reps-ux (où va chaque donnée, mots courts).

## Format du rapport
Un tableau, classé du plus grave au moins grave :

| Gravité | Où (`fichier:ligne`) | Problème | Scénario qui le montre |
|---|---|---|---|

Gravité : **bloquant** (faux, plante, contredit une décision), **à corriger**, **remarque**.
Les remarques ne déclenchent pas de correction dans ce cycle : elles vont au backlog.
Si rien n'est bloquant ni à corriger, le rapport le dit en une ligne.
