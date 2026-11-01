# Grille de relecture (Reviewer)

Une relecture par lot. Le Reviewer **signale, ne conçoit pas** : pas de nouvelle fonction, pas
de changement de design. Il lit le diff du lot, `CLAUDE.md`, le skill reps-ux et `DECISIONS.md`,
puis rend **un seul rapport** au Builder.

## À vérifier
0. **Besoins de l'utilisateur** (CLAUDE.md, « L'expérience ») : pour chaque écran touché, ouvert
   sans rien savoir du code. L'utilisateur sait-il où il en est dans son plan, ce qui vient,
   quand et pourquoi ? Chaque proposition dit-elle pourquoi, en mots de tous les jours ? Un
   changement de plan est-il annoncé avec sa raison ? Reste-t-il un sigle ou un symbole seul ?
   Plus de trois informations à chaud ? Un écart au plan est-il puni ? Chaque « non » est au
   moins « à corriger ».
0 bis. **Typographie et espace** (skill reps-ux, § 12) : une taille hors de l'échelle (34, 22, 17,
   15, 13) ou sous 13 pt ; une carte avec plus d'une idée ; un paragraphe là où une phrase suffit ;
   une marge sous 20 pt entre ou dans les cartes. Chaque cas est « à corriger ».
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
