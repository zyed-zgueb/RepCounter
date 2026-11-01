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

**Statut** : lancé le 01/11 (répond à un retour de Vincent).

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

## Cycle 3 : à chaud, comme un coach

**Statut** : en construction depuis le 01/11 au soir (avis de Vincent sur la maquette et sur les
Nouveautés, `DECISIONS.md`).

**Objectif (vérifiable)** : sur les captures de la CI (série, repos, fin de séance, en grand texte
aussi), trois informations au plus pendant la série et le repos, et une fin de séance en trois
blocs ; les 7 « À revoir » des Nouveautés corrigés.

**Ce que Vincent vivra**
- Pendant la série : un segment du cadran s'allume à chaque répétition jusqu'à la cible ; le
  nombre et « sur 28 » en grand ; « Série 2 sur 3 ».
- Pendant le repos : un compte à rebours ; la série suivante et sa cible en grand ; pourquoi si
  elle a baissé.
- Fin de séance : cible atteinte ou pas, la suite, un conseil quand une mesure le justifie ; le
  détail sur une page à part ; « Effort ? » reste.
- Corrections : « effort normal » avec une petite jauge ; jour de test clair (chiffre à battre en
  grand, « En savoir plus ») ; « record : N » de toujours ; « reps » ; plus de puce ni de nom de
  capteur sous la question de fatigue.

## Feuille de route (décidée par le Builder le 01/11)

Chaque cycle : **maquette visuelle** au cadrage (si un écran change) → construction → relecture
fonctionnelle → **revue de design sur captures d'écran de l'app réelle** → livraison → recette.
Les captures automatiques par la CI sont mises en place avant le cycle 3. Une **revue de design de toute l'app** tous les deux cycles.

| Cycle | Ce que Vincent vivra | Revue de design |
|---|---|---|
| **2** (en cours) | Le plan visible et compris ; textes plus grands, cartes aérées. | Écrans du Coaching ; puis **revue de toute l'app** (après la recette). |
| **2 bis** (outillage, en cours le 01/11) | Rien de visible : des captures de tous les états importants (jour de test, repos conseillé, série, récupération, fin de séance, semaines), en grande taille de texte aussi, et des tests Swift du plan dans la CI (`Process/RETRO.md`). | Les captures elles-mêmes. |
| **3** | **Pendant et juste après l'effort, comme un coach** : 3 informations au plus pendant la série et la récupération ; fin de séance = cible atteinte ou pas, la suite de la journée, un conseil concret quand les mesures le justifient (« En savoir plus » pour le détail). | Cadran, récupération, fin de séance. Premières **captures d'écran automatiques** par la CI, pour relire le design sur de vraies images. |
| **4** | **Le Coaching et l'Historique allégés** (dont ~60 textes encore lus à 13 pt, à passer à 15 ou 17 ; 13 réservé aux libellés de graphique) : objectif, chemin, état, 12 semaines, journal, une idée par carte ; plus d'abréviations ni de légendes manquantes ; les longues explications du (i) deviennent des « En savoir plus » au bon endroit. | Coaching et Historique ; puis **revue de toute l'app**. |
| **5** | **Un compteur toujours juste** : nouveaux enregistrements réels, profils non validés (Développé épaules), ligne du jour qui change à minuit. | Écrans de mise en place et de comptage. |
| **6** | **Prêt pour l'App Store** : fiche, captures, premier lancement. | Revue de toute l'app, en conditions de première ouverture. |

L'ordre suit les besoins de l'utilisateur (contrôle, compréhension, charge mentale) ; un retour de
Vincent à la recette peut l'avancer ou le changer.

## Backlog
- **Cycle 3 proposé : la fin de séance, comme un coach.** Recette du cycle 1 : « grosse
  densité d'infos, surcharge cognitive ». Ce que Vincent veut y voir (31/10) :
  1. objectif atteint ou pas ;
  2. la suite pour la journée ;
  3. un conseil concret quand les mesures le justifient (« cette série montre que tu es
     fatigué, je te conseille de… »), comme le ferait un coach.
  Le cycle couvre tout ce qui se voit à chaud, relevé par l'audit UX du 01/11 : pendant la série
  (« Série 02 », « T+ 03:12 », compteur, « sur 25 », cases des séries : plus de 3 informations),
  pendant la récupération (« 0:45 sur 1:30 », « Ensuite · série 2 · ! cible réajustée »), la fin
  de séance (une dizaine d'informations), et la numérotation des séries quand des séries ont déjà
  été faites plus tôt dans la journée (« Série 01 » puis « Ensuite · série 3 »).
  Tout le reste quitte cet écran (il reste disponible dans l'historique). Conseils : seulement
  sur ce que l'app mesure vraiment (répétitions face aux cibles, ralentissement des
  répétitions, repos, « Effort ? », Forme) et avec une base (source ou choix de l'app
  assumé) ; pas de conseil quand la mesure est douteuse.
- Abréviations restantes (audit UX du 01/11) : « réf. 2 / 3 », « +3 vs mardi 27 », « reps / sem. »,
  « moy. 64 » ; légende du chemin sans « ⚑ », « ▼ », « ! » ; formules de la page Endurance.
- Le point de couleur sur l'icône Coaching garde « séance prévue » un jour de repos conseillé.
- Journal : les pointillés des jours sans séance sont trop pâles pour être vus (recette du cycle 1).
- Rafraîchir la ligne du jour au passage de minuit, app ouverte (aucun observateur aujourd'hui ;
  relecture du cycle 1).
- Audit complet de la planification. Les textes intégraux restent bloqués par le réseau de
  l'environnement : on continue avec les résumés (décision du Builder, 31/10).
- Nouveaux enregistrements réels du compteur (Développé épaules non simulé).
- Fiche App Store (tickets `lancement`, session marketing du 28/10).
