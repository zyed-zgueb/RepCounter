# Protocole de mesure de la précision

Le facteur clé de succès : **un compte juste, sans toucher l'écran, dès la première séance**,
pour n'importe qui. Ce protocole mesure ce point sur de vraies séances, exercice par exercice,
avant le lancement. On n'améliore le compteur que sur ce que ces mesures montrent.

## Critères de lancement (par exercice et par mode)

| Mesure | Objectif |
|---|---|
| Séries comptées exactement | ≥ 95 % |
| Répétitions comptées en trop au repos (téléphone qu'on pose, qu'on reprend, qu'on règle) | 0 |
| Série qui ne démarre pas (rien compté alors qu'on enchaîne) | 0 |
| Fin de série détectée (la récupération démarre seule) | 100 % |
| Personnes différentes | ≥ 3, de gabarits différents |

Un exercice qui ne passe pas ces critères ne sort pas au lancement (il reste masqué).

## Deux sources de mesure

1. **Au quotidien** (Réglages › Analyse › mode analyse) : la liste *Précision du comptage*.
   Elle se calcule toute seule à partir des corrections faites en fin de séance. Règle
   absolue : **corriger chaque série fausse**, sinon elle compte comme exacte.
2. **Enregistrements ●** (mode analyse) : la séance complète, rejouable. À faire pour chaque
   cas ci-dessous et pour toute séance qui compte mal. À la fin, indiquer le nombre réel de
   répétitions, partager le fichier et le déposer dans `Recordings/`.

Rejouer tout le corpus et vérifier qu'aucune correction n'a cassé un cas qui marchait :

    python3 Simulation/benchmark.py

## Les cas à enregistrer (pour chaque exercice)

Une séance de 3 séries par cas, avec ~1 min de repos, en notant le nombre réel de répétitions.

1. **Normal** : rythme habituel, placement de la consigne.
2. **Lent puis rapide** : 1re série lente (3 s par répétition), 2e rapide, 3e à l'échec
   (les dernières répétitions ralenties, incomplètes).
3. **Les pièges** : poser le téléphone et le reprendre, se gratter, boire, se replacer entre
   les séries ; une pause de 5 s au milieu d'une série.
4. **Placement imparfait** : téléphone un peu de biais, plus loin ou plus près que la
   consigne ; pour la caméra, contre-jour ou lumière faible.
5. **Une autre personne** : même séance, autre gabarit (taille, souplesse, vitesse).

## Ordre de priorité

1. Les exercices par défaut du cadran : pompes, abdos, squats, fentes, tractions.
2. Biceps et développé à la caméra (iPhone posé), puis avec brassard.
3. Dips, rowing, Autre.

## État actuel du corpus

| Exercice | Mode | Enregistrements | Personnes | Statut |
|---|---|---|---|---|
| Abdos | mouvement | 5 | 1 | exact (273/273), dont une série irrégulière et une séance piège |
| Pompes | caméra | 4 | 1 | exact (83/83), dont deux séries à l'échec (32, 31) |
| Squats | mouvement | 1 | 1 | exact (20/20) |
| Tractions | mouvement | 1 | 1 | exact (5/5) après correction (l'app en comptait 8 : sens de comptage hérité de la séance précédente) |
| Tous les autres | — | 0 | 0 | non validé (simulation seulement) |

## Séries à l'échec (répétitions en réserve, priorité 2)

Pour valider l'estimation des répétitions en réserve et du max, il faut des séries menées
**jusqu'à l'échec** : la dernière répétition tentée ne passe pas. Objectif : **au moins 10 séries
à l'échec par exercice** (tractions d'abord, puis pompes, puis squats avec barre), sur plusieurs jours, idéalement de
plusieurs personnes. Critère d'acceptation de l'estimation : erreur médiane de ±2 répétitions
au plus, 3 répétitions avant l'échec.

1. Mode analyse, enregistrement ● lancé avant la série.
2. Échauffement léger, puis **une seule série par enregistrement**, au maximum, à rythme
   naturel et constant (aussi vite que possible à la montée, sans pause en haut ni en bas).
3. Arrêter à l'échec : la répétition qui ne passe pas (tractions : menton sous la barre ;
   pompes : poitrine qui ne remonte pas) ne compte pas.
4. À la fin, indiquer le nombre réel de répétitions **réussies**, et dans le nom ou la note du
   fichier : `echec`, l'exercice, le repos depuis la dernière série (au moins 3 min).
5. Tractions : iPhone dans la poche avant du pantalon (ajusté), écran contre la cuisse,
   toujours dans le même sens. Pompes : iPhone au sol, sous le visage (caméra).
   Squats **avec barre** (les équations publiées ne couvrent que le squat chargé) : iPhone dans
   la poche, charge notée (barre + disques) ; à l'échec, la remontée qui ne passe pas ne compte
   pas — avec un pareur ou des sécurités. Le squat sans charge n'a pas d'étude : pas de série à
   l'échec à enregistrer.
6. Si possible, filmer la série de profil à 120 ou 240 images/s (ralenti de l'iPhone d'un
   proche) : la vidéo, analysée image par image, sert de référence de vitesse.

Les séries corrigées à la main (compte faux) sont exclues de la validation. Chaque série à
l'échec est déclarée dans `Recordings/echec.json` (exercice, répétitions réussies) ; puis :

    python3 Simulation/failure.py

ajuste la relation perte de vitesse → part des répétitions faites et la valide en laissant une
série de côté. Séries à l'échec à ce jour : pompes 2 / 10.
