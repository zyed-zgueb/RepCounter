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

## Cycle 2 (proposé) : le plan, visible et compris

**Statut** : proposé à Vincent le 01/11, en attente de son accord.

**Pourquoi** (recette du cycle 1, Vincent) : « Je dois faire un test de max sans comprendre dans
quoi il s'inscrit. » Le besoin de contrôle n'est pas satisfait : le plan existe dans l'app mais
ne se lit pas. Constat du Builder : un jour de test, l'écran dit seulement « ◆ test 1 / 2 · série
max » ; la carte Bloc parle en sigles (« B1 · P1 », « A », « ◆ ») ; la raison des tests et des
semaines n'est que dans le (i) ; et le cycle 1 a rendu le test de départ proposable n'importe
quel jour de la première semaine, sans prévenir.

**Ce que Vincent vivra dans l'app**
1. **Le plan, daté, en mots** : en tête du Coaching, le bloc en cours semaine par semaine, avec
   dates et but (« mesurer ton niveau », « progresser », « récupérer », « test : mesurer ton
   progrès »), « tu es ici », et le prochain test daté.
2. **Le pourquoi de chaque jour** : la proposition du jour dit sa raison en une phrase et ce qui
   suit (« Test 1 sur 2 : il mesure ton niveau de départ. Tes cibles des 3 prochaines semaines
   en partiront. Prochain test : lundi 30 novembre. »).
3. **Pas de surprise** : les 2 tests de départ sont annoncés à l'avance, à des jours fixés ; tout
   changement du plan (semaine refaite, test décalé, cibles relevées) est dit au moment même,
   avec la raison et la nouvelle date.
4. **Plus de sigles** : des mots partout où l'on voyait « B1 · P2 », « A », « ◆ ».

**Dehors** : la fin de séance (cycle 3) ; tout nouveau réglage.

## Backlog
- **Cycle 3 proposé : la fin de séance, comme un coach.** Recette du cycle 1 : « grosse
  densité d'infos, surcharge cognitive ». Ce que Vincent veut y voir (31/10) :
  1. objectif atteint ou pas ;
  2. la suite pour la journée ;
  3. un conseil concret quand les mesures le justifient (« cette série montre que tu es
     fatigué, je te conseille de… »), comme le ferait un coach.
  Tout le reste quitte cet écran (il reste disponible dans l'historique). Conseils : seulement
  sur ce que l'app mesure vraiment (répétitions face aux cibles, ralentissement des
  répétitions, repos, « Effort ? », Forme) et avec une base (source ou choix de l'app
  assumé) ; pas de conseil quand la mesure est douteuse.
- Journal : les pointillés des jours sans séance sont trop pâles pour être vus (recette du cycle 1).
- Rafraîchir la ligne du jour au passage de minuit, app ouverte (aucun observateur aujourd'hui ;
  relecture du cycle 1).
- Audit complet de la planification. Les textes intégraux restent bloqués par le réseau de
  l'environnement : on continue avec les résumés (décision du Builder, 31/10).
- Nouveaux enregistrements réels du compteur (Développé épaules non simulé).
- Fiche App Store (tickets `lancement`, session marketing du 28/10).
