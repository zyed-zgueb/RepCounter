# Jours d'entraînement : N jours au plus

Session « Science du sport », 31 octobre 2026. **Validé par Vincent.**

Décision de Vincent : la personne indique combien de jours par semaine elle veut s'entraîner, au
plus (N). Le plan s'adapte à ce nombre, et l'app peut placer un repos sur un jour choisi. Cette
décision remplace la réinitialisation du commit 72c3383.

Sources : ACSM 2026 (Currier et al., *Med Sci Sports Exerc* 58(4):851–872), citations relevées
dans le PDF par la session Produit (C). Les autres sources ont été lues en résumé seulement (R) :
le réseau bloque toujours les textes intégraux.

## Les règles

| # | Règle | Base | Statut |
|---|---|---|---|
| 1 | **Séance identique, N séances.** Chaque séance garde le même contenu : 3 séries, série 1 = max − 3, puis la baisse habituelle. Le volume de la semaine = N séances. On ne répartit pas un volume fixe sur N jours. | ACSM 2026 : « at least two sets per exercise », gains décroissants au-delà de « ~2–3 sets/exercise » (p. 864, C). Le volume d'une séance a donc déjà sa bonne taille ; il n'y a pas lieu de la gonfler ou de la réduire selon N. À volume égal, la fréquence change peu le résultat (Grgic 2018, méta-analyse, R). | Sourcé pour la séance ; la règle « N séances » est un choix de l'app |
| 2 | **Placement.** Les séances vont sur les jours choisis. Sans choix, elles sont espacées au mieux : 2 → lundi, jeudi ; 3 → lundi, mercredi, vendredi ; 4 → lundi, mardi, jeudi, vendredi (inchangé). | L'ACSM ne fixe pas l'espacement. | Choix de l'app (inchangé) |
| 3 | **N trop bas.** N = 1 est accepté, avec la mention : « Moins que le minimum conseillé : au moins 2 séances par semaine ». La séance n'est pas allongée pour compenser. | ACSM 2026 : « at least twice weekly » (p. 863, C). Pas de compensation : au-delà de ~2–3 séries par exercice, le gain décroît (p. 864, C). | Sourcé (minimum) ; pas de compensation = choix de l'app |
| 4 | **N élevé.** N jusqu'à 7 est accepté. À 7 séances de 3 séries, on atteint 21 séries par semaine. | ACSM 2026 : rendements décroissants au-delà de « ~18–20 weekly sets » pour l'hypertrophie (p. 864, C). Pour l'endurance, aucune donnée (p. 859, C). Rien ne justifie un plafond plus bas. | Pas de plafond ; choix de l'app |
| 5 | **Repos placé par l'app sur un jour choisi**, dans deux cas seulement : (a) **la veille du test**, la séance prévue devient un repos ; (b) **phase « Fatigue persistante »** : repos jusqu'à ce que la phase change. | (a) La performance est meilleure après une baisse de volume (Bosquet 2007, méta-analyse sur l'affûtage, R) : c'est une analogie, la veille est un choix de l'app. (b) Action déjà validée pour cette phase (Meeusen 2013, R). | (a) choix de l'app ; (b) inchangé |
| 6 | **Pas de repos ajouté pour une Forme basse** : c'est une séance légère (la moitié des séries), comme aujourd'hui. Pas de repos non plus pour des jours consécutifs choisis par la personne. | Aucune étude ne justifie de transformer une séance en repos sur ces signaux. Le ressenti suit la charge (Saw 2016, R), d'où l'allègement plutôt que l'arrêt. | Choix de l'app (inchangé) |
| 7 | **Le jour de test** est le premier jour choisi de la semaine qui suit la semaine allégée. Il compte comme une des N séances de sa semaine. Si ce jour est passé sans test, le test reste « à faire » les jours choisis suivants (METHODE-TEST.md, 7 jours). | METHODE-TEST.md | Choix de l'app (déjà validé) |
| 8 | **Séances manquées et semaine refaite** : on compte par rapport aux N jours choisis, moins les repos placés par l'app (règle 5). Un repos placé par l'app n'est jamais une séance manquée. | — | Choix de l'app |
| 9 | **Séance faite un jour non choisi** : elle compte et remplace la prochaine séance prévue (inchangé). On n'ajoute jamais une séance au-delà de N. | — | Choix de l'app (inchangé) |

## Ce qui change par rapport au code actuel

- N vient du choix de la personne, et non plus de son habitude des 4 dernières semaines. Sans
  choix, l'habitude reste le défaut.
- Nouveau : un repos placé la veille du test (règle 5a).
- Nouveau : la mention pour N = 1 (règle 3).
- Nouveau : un repos placé par l'app ne compte pas comme une séance manquée (règle 8).
