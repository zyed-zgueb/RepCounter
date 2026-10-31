# Méthode du test annoncé

Session « Science du sport », 30 octobre 2026.

Décision de Vincent (point 9 de l'audit) : le test est **annoncé**. Le jour de test est visible et
la personne lance elle-même la série max. Aucune série n'est plus prise par défaut. Les garde-fous
déjà codés restent : une première série à 0 est ignorée, et une séance tout à 0 ne compte pas.

Avertissement : le réseau bloque toujours les textes intégraux. La seule citation vérifiée est
celle de l'ACSM 2026, relevée dans le PDF par la session Produit. Le reste vient de résumés ou de
sources secondaires (marqué R ou S). Faute de preuve, la plupart des règles sont des
**choix de l'app**, et doivent être marquées ainsi dans le code et dans le (i).

## Les règles

| # | Règle | Base | Statut |
|---|---|---|---|
| 1 | **Pourquoi tester** : le test recale la cible du bloc suivant sur le niveau réel. | ACSM 2026, Currier et al., *Med Sci Sports Exerc* 58(4):851–872, p. 863 : « the same relative load can also be sustained when regular strength testing is performed […] to increase absolute load commensurate with strength gains » (citation relevée par la session Produit) | Sourcé |
| 2 | **Quand** : à partir du premier jour de séance prévu après la semaine allégée. Le test est annoncé ce jour-là (« Jour de test »). | Un volume réduit avec intensité gardée précède les meilleures performances : Bosquet 2007, méta-analyse sur l'affûtage (R). La transposition à une semaine allégée avant un test est une analogie. | Choix de l'app, appuyé par analogie |
| 3 | **Lancement** : la personne lance le test elle-même (mode test). Seules les séries faites en mode test comptent comme test. | Décision de Vincent | Règle produit |
| 4 | **Échauffement recommandé, non compté** : avant le test, une série facile d'environ un tiers du dernier max, arrêtée loin de l'échec, puis 2 minutes de repos. Elle se fait avant de lancer le mode test, ou dans le mode test, marquée « échauffement ». | Les guides de test recommandent un échauffement standardisé et un temps de récupération avant un test max (S : guide de tests Topend Sports ; procédures de test de force de type NSCA, relayées par un guide de préparation). Aucune étude trouvée sur l'échauffement avant un max de pompes. Le tiers et les 2 minutes ne sont pas sourcés. | **Choix de l'app** |
| 5 | **Ce qui compte comme test** : la meilleure série faite en mode test ce jour-là. Une seule série suffit. Une 2e tentative est possible, après au moins 3 minutes de repos. | Un repos de 3 à 5 minutes permet de refaire plus de répétitions qu'un repos court : de Salles et al. 2009, revue (R). La règle du meilleur essai n'est pas sourcée. | **Choix de l'app** |
| 6 | **Fin de la série** : la fin de série détectée par le compteur (arrêt, ou plus de répétition complète). Pas de règle de tempo. | Les protocoles publiés (Cooper Institute, CSEP) fixent la forme et la fin du test (S). Je n'ai pas pu les lire. | Choix de l'app, à revoir sur texte intégral |
| 7 | **Bloc 1 (calibrage)** : 2 tests la première semaine, sur 2 jours différents. Le meilleur sert de départ. | Familiarisation recommandée avant un test de répétitions max ; fiabilité correcte après familiarisation (étude sur le test à 8 répétitions max ; études de fiabilité des tests de pompes chez les jeunes) (R) | Appuyé faiblement ; 2 tests = choix de l'app |
| 8 | **Test pas lancé le jour prévu** : le test reste « à faire » à chaque jour de séance suivant. En attendant, la séance du jour reste proposée (cibles de la semaine allégée). Le bloc suivant ne commence qu'après le test. | — | **Choix de l'app** |
| 9 | **Test pas lancé une semaine après le jour prévu**, alors que la personne s'entraîne : le bloc suivant démarre sur le dernier max, sans recalage. Le test est proposé à la fin de ce bloc. | — | **Choix de l'app** ; le seuil de 7 jours est celui de `repriseDays` |
| 10 | **Lecture du résultat** : un écart de moins d'environ 10 % avec le test précédent ne se lit ni comme un progrès ni comme un recul. La cible suit quand même le nouveau test. | D'un test à l'autre, le max de pompes varie de 10 à 20 % chez des débutants (études de fiabilité, R). Le principe (plus petit changement significatif) vient de Hopkins 2000 et 2004, déjà utilisés dans `Progress.swift`. | Principe sourcé ; 10 % provisoire |

## Seuils de temps : il n'y en a que deux

Pour éviter des seuils contradictoires dans le code, j'**abandonne le seuil de 14 jours** de ma
première version. Il ne reste que les deux seuils déjà validés par Vincent (609d333), tous deux
des choix de l'app :
- **7 jours** (`repriseDays`) :
  - plus de 7 jours sans séance avant le test → une semaine de reprise, puis le test ;
  - le test n'est pas lancé 7 jours après le jour prévu → le bloc suivant repart du dernier max.
- **28 jours** (`comebackDays`) : plus de 28 jours sans séance → nouveau bloc 1, avec calibrage.

Le 7 jours rejoint aussi la « Pause » des phases (`breakDays` = 7).

## Cas limites (signalés par la relecture)

Toutes ces règles sont des **choix de l'app** : aucune étude ne les traite.

| Cas | Règle |
|---|---|
| Test lancé **pendant la semaine allégée**, avant le jour prévu | Il compte et clôt le bloc. Le bloc suivant commence la semaine d'après. |
| Test « à faire » **et pause sans séance** | Les seuils validés par Vincent (609d333) s'appliquent et priment. **Plus de 7 jours** sans séance avant le test : une semaine de reprise, puis le test (`repriseDays`). **Plus de 28 jours** sans séance : nouveau bloc 1, avec ses 2 tests de calibrage (`comebackDays`). Plus l'arrêt est long, plus le niveau perdu est grand (Bosquet 2013, méta-analyse, résumé seulement), d'où le recalage complet après une longue pause. Les deux seuils sont des choix de l'app. |
| **Tests sur plusieurs jours** | On retient le meilleur des tests faits entre le premier test et le début du bloc suivant. Au bloc 1, c'est le meilleur des 2 tests de calibrage. |
| Mode test **abandonné sans série > 0** | Pas de test. Il reste « à faire ». |
| **Séances normales** pendant que le test est « à faire » | Elles comptent comme séances, avec les cibles de la semaine allégée. Elles ne servent ni de test ni de séance habituelle, comme les séances de semaine allégée aujourd'hui. |
| Test lancé **pendant une semaine de progression** | Il ne clôt pas le bloc. S'il dépasse le max en cours, il devient le nouveau max, comme toute série au-dessus du max (voir « Max relevé en cours de bloc »). **Les cibles se recalculent dès la séance suivante**, dans le même bloc (max − 3, puis la baisse habituelle). |
| Exercice **« Autre »** | Pas de mode test : ses séances mêlent plusieurs mouvements, un max n'y a pas de sens. |
| Exercice **sans objectif** | Mode test identique : le plan existe sans objectif (Coaching). |

## Max relevé en cours de bloc

**Règle proposée** : toute série qui dépasse le max en cours en devient le nouveau max.
**Nouveau max = les répétitions faites dans cette série.** Les cibles se recalculent dès la séance
suivante (nouveau max − 3, puis la baisse habituelle).

- C'est une mesure : on sait seulement que la personne a fait N répétitions, et qu'elle en avait
  peut-être d'autres en réserve. Le max est donc au moins N.
- La formule « max + dépassement », codée au commit 31c8351 (cible 12, fait 15 → max 18), est
  **retirée**. Elle suppose qu'il restait encore 3 répétitions en réserve après la série, ce que
  rien ne mesure. La personne a pu s'arrêter à l'échec. De plus, chacun se trompe d'environ une
  répétition en estimant ce qu'il lui reste, davantage sur les séries longues (Halperin et al.
  2022, méta-analyse ; résumé seulement).
- Si la personne pouvait faire plus, le test de fin de bloc le mesurera.
- Le déclencheur devient « série > max ». Il remplace « série ≥ cible + 3 » de l'audit, qui donne
  la même chose sans le supposer.
- Choix de l'app, fondé sur une mesure.

## Calibrage d'un plan déjà commencé

Un utilisateur dont le plan est en semaine 1 se voit proposer les 2 tests de calibrage. S'il n'en
fait aucun, le repli est le calibrage par séances, qui existe déjà (les cibles suivent les séances
de la semaine 1, puis sont figées). Choix de l'app. Les tests sont préférables (familiarisation,
résumés seulement) mais pas obligatoires.

## À afficher (pour la session Produit)

- Jour de test visible dans le Coaching, avec le bouton pour lancer le test.
- Le conseil d'échauffement : une série facile, puis 2 minutes de repos.
- Pendant le test : pas de cible, série max.
- Un test non fait reste « à faire ». 7 jours après le jour de test prévu, le bloc suivant démarre
  le lundi qui suit, sur le dernier max.
- Dans le (i) : la règle 1 est sourcée (ACSM 2026) ; les règles 4, 5, 6, 8 et 9 sont des choix de
  l'app.

## À vérifier sur texte intégral

Dès que le réseau est ouvert ou que les PDF sont transmis :
- les protocoles de test de pompes : CSEP-PATH, ACSM Guidelines, Cooper Institute ;
- les études de fiabilité et de familiarisation ;
- de Salles 2009 ; Bosquet 2007 et 2013.
