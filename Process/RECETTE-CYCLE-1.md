# Recette du cycle 1

**Cycle** : 1, le coach décide des jours   **Branche** : `claude/awesome-dirac-n1emli`
**Commit** : 5744cc2 (affiché en bas des Réglages)   **CI** : en attente sur 5744cc2 (verte
sur le lot 40492f9 : compilation iOS, simulation du compteur, simulation du plan)

## Ce qui a changé
- Plus aucun réglage de jours : chaque jour, l'app propose une séance, ou « repos conseillé »
  avec sa raison.
- Un repos n'est qu'une proposition : « Démarrer quand même » reste là, et la séance compte.
- Plus de « séance manquée » nulle part.

## À vérifier sur l'iPhone
- [ ] **Coaching › carte Bloc** : plus de rangée L M M J V S D ni de bouton « ✎ jours ».
- [ ] **Cadran en veille, jour ordinaire** : « aujourd'hui · 29 · 25 · 22 · repos 1:30 » (vos
      cibles), et la carte Aujourd'hui du Coaching propose la séance avec « Démarrer ».
- [ ] **Faire une séance** puis revenir au cadran : « fait ✓ · prochaine demain ».
- [ ] **Noter « Effort ? » à 7 ou plus** en fin de séance. Le lendemain : sous le cadran
      « repos conseillé · séance d'hier très difficile », et dans le Coaching la même raison,
      la prochaine séance et « Démarrer quand même ».
- [ ] **Ce jour-là, démarrer quand même** et finir la séance : elle compte (« fait ✓ »).
- [ ] **Fin de séance** : la ligne dit « séance N de la semaine », sans « / 4 ».
- [ ] **Historique › Journal** : les jours sans séance sont en pointillés, jamais
      « ! prévue, manquée ».
- [ ] **Coaching › (i) › Les jours** : le nouveau texte (pas de jours à choisir, les 4 cas de
      repos, le minimum de 2 séances).

Selon le moment du bloc, si l'occasion se présente : la veille du test (dimanche de la semaine
allégée), « repos conseillé · test demain » ; le jour du test, le test est proposé même après
une séance difficile la veille.

## Décisions prises en route
- Une semaine de progression est refaite sous 2 séances (une seule exigée la semaine où le plan
  commence en cours de semaine).
- Le jour de test est le lundi qui suit la semaine allégée.
- Un jour de test, seule la fatigue persistante conseille un repos : l'effort noté après une
  série max (souvent 9–10) ne repousse pas le test suivant.
- En fatigue persistante, « Démarrer quand même » lance la séance légère.
- Les barres « prévu face au fait » comparent le fait aux cibles des séances faites.

## Hors cycle (backlog)
- Rafraîchir la ligne du jour au passage de minuit quand l'app reste ouverte.
