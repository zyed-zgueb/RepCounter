# Fréquence : le coach décide chaque jour

31 octobre 2026. **Décision de Vincent** : pas de réglage de jours. Les pompes sont un exercice
court, qui se glisse n'importe quand dans une journée : l'app, en coach, suppose qu'on peut
s'entraîner tous les jours. Chaque jour, elle propose une séance ou un repos, selon ce qu'elle
sait. Cette décision remplace la version « N jours au plus » de ce fichier (même jour, git) et
la réinitialisation des jours de 72c3383 / ef25a42.

Les règles ci-dessous sont celles du Builder pour appliquer cette décision. Sources : ACSM 2026
(Currier et al., *Med Sci Sports Exerc* 58(4):851–872), citations relevées dans le PDF (C) ;
les autres en résumé seulement (R), le réseau bloquant toujours les textes intégraux.

## Les règles

| # | Règle | Base | Statut |
|---|---|---|---|
| 1 | **Aucun réglage de jours ni de nombre de séances.** Chaque jour, l'app affiche « séance » ou « repos conseillé ». | Décision de Vincent. À volume égal, la fréquence change peu le résultat (Grgic 2018, méta-analyse, R) : rien n'impose des jours fixes. | Décision |
| 2 | **Séance par défaut**, au contenu inchangé : 3 séries, série 1 = max − 3, puis la baisse habituelle. | ACSM 2026 : « at least two sets per exercise », gains décroissants au-delà de « ~2–3 sets/exercise » (p. 864, C). | Sourcé (inchangé) |
| 3 | **Repos conseillé** dans quatre cas seulement : (a) la veille du test ; (b) phase « Fatigue persistante » ; (c) la séance de la veille a été notée « Très difficile » (Effort ≥ 7) ; (d) 20 séries faites sur les 7 derniers jours. | (a) Bosquet 2007, affûtage, R : analogie. (b) Meeusen 2013, R, déjà validé. (c) choix de l'app : deux jours après un effort maximal. (d) ACSM 2026 : rendements décroissants au-delà de « ~18–20 weekly sets » (p. 864, C), établi pour l'hypertrophie ; pour l'endurance, aucune donnée (p. 859, C). | (a), (c), (d) choix de l'app ; (b) inchangé |
| 4 | **Forme basse ou « Fatigue ? » à 1–2** : séance légère (la moitié des séries), pas de repos. | Le ressenti suit la charge (Saw 2016, R) : on allège plutôt que d'arrêter. | Choix de l'app (inchangé) |
| 5 | **Un repos est une proposition.** Une séance faite un jour de repos compte normalement. Un jour sans séance n'est jamais une « séance manquée ». | Décision de Vincent (« elle me le propose »). | Décision |
| 6 | **Minimum** : moins de 2 séances sur les 7 derniers jours → une ligne discrète « au moins 2 séances par semaine ». Rien de plus. | ACSM 2026 : « at least twice weekly » (p. 863, C). | Sourcé |
| 7 | **Le test** est proposé le premier jour qui suit la semaine allégée et reste « à faire » 7 jours (METHODE-TEST.md). | METHODE-TEST.md | Déjà validé, jour fixe retiré |
| 8 | **Les blocs** restent en semaines (3 semaines + semaine allégée + test). Les cibles ne dépendent plus d'un nombre de séances par semaine. | Inchangé | Choix de l'app (inchangé) |

## Ce qui disparaît du code
- La rangée des jours, « ✎ jours », la feuille « Jours d'entraînement », « Jours réinitialisés ».
- Les jours enregistrés (`Schedule.saved`), les jours par défaut, le nombre de séances par
  semaine tiré de l'habitude (`perWeek`), « semaine faite 2/4 ».
- Les séances manquées du journal et de l'historique.
