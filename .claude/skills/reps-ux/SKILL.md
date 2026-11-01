---
name: reps-ux
description: Règles d'organisation des écrans de Reps (compteur, fin de séance, Coaching, historique). À charger avant de concevoir, maquetter ou modifier un écran, une donnée affichée ou un texte de l'app.
---

# Reps : où va chaque donnée

Ce skill est modifié par le Builder seulement, après validation de Vincent (CLAUDE.md).

Beaucoup de données, mais séparées et structurées. Ce qu'on voit tout le temps n'est pas traité comme ce qu'on voit de temps en temps. On rassemble ce qui se ressemble ou se complète.

## 1. La fréquence de lecture décide de la place et du traitement

| Fréquence | Où | Traitement |
|---|---|---|
| Chaque répétition | Cadran | sans lire : très grand chiffre, couleur, son, vibration |
| Chaque série | Cadran | un coup d'œil : formes et couleurs, trois mots au plus |
| Chaque séance | Veille (avant), fin de séance (après) | une ligne avant ; un bilan court après |
| Chaque semaine | Coaching | écran ouvert exprès : cartes, frise, tableau |
| Chaque bloc | Test, Coaching | un moment marqué : un chiffre, un verdict, un graphique |
| De temps en temps | Historique, (i), Réglages | riche : graphiques, explications, sources |

Plus une donnée est vue souvent, plus elle est réduite et proche du compteur. Plus elle est rare, plus elle peut être détaillée et loin de lui.

## 2. Une responsabilité par écran

- **Compteur (veille et série)** : il compte. Rien d'autre que des indices discrets : une ligne « aujourd'hui · 4 × 15 » sous le cadran, un point d'état sur l'icône Coaching. Jamais la vue complète d'un bloc ou d'un plan.
- **Fin de séance** : la séance seulement. Prévu face au fait série par série, « Effort ? », records battus, une ligne qui situe la séance dans la semaine.
- **Test de fin de bloc** : le résultat seulement (mesuré, attendu, gain). Le bloc suivant se découvre dans le Coaching.
- **Coaching** (icône cible) : l'avenir et le plan.
- **Historique** (icône graphique) : le passé.
- **(i) et Réglages** : la méthode, les références, le profil.

## 3. Rassembler ce qui se ressemble ou se complète

- **Où je vais** (Coaching, un exercice en titre, glissement pour passer à un autre) : d'abord la séance du jour (carte Aujourd'hui : la raison du jour en une ou deux phrases de tous les jours, puis cibles en barres, repos, intensité, Démarrer ; ou « repos conseillé » et sa raison, avec la prochaine séance et « Démarrer quand même » ; la ligne sous le cadran en est le résumé ; aucun réglage de jours : le coach décide chaque jour, Science/METHODE-JOURS.md), puis **Ton plan** (le bloc en frise verticale datée : une ligne par semaine avec son but en mots, « tu es ici », puis le test daté avec sa raison ; c'est la carte qui donne le contrôle), puis l'objectif et où j'en suis (ou, sans objectif, une invitation avec une proposition), le chemin (seulement avec un objectif). Sans objectif, le plan tourne quand même : l'écran ne se vide jamais.
- **Comment je suis** (carte État, dans le Coaching) : phase, Forme mesurée, ressenti (fatigue, effort). Une seule carte, jamais dispersée.
- **D'où je viens** (Historique) : deux cartes. Strictement deux cartes. « 12 semaines » : la meilleure série en courbe (★ records) et le volume en barres, sur le même axe ; en tête le verdict de progression du score d'endurance (« ▲ en progrès », « = stable », « ▼ en recul », rien tant qu'il n'est pas établi) ; la tendance du volume étiquette les barres (« reps / sem. · ▲ 4 % »). Le score d'endurance n'a pas sa propre carte : il dit comment la performance évolue, comme « 12 semaines » ; son détail ouvre la page **Progrès** (score d'endurance, volume détaillé, régularité) en touchant la carte. « Journal » : les jours sur une frise horaire. La semaine en cours se lit dans le journal ; le suivi du plan (fait face au prévu) reste dans le Coaching.

## 4. Le cadran

- Deux anneaux. **Extérieur : il compte.** Toujours 10 segments, un par répétition ; le tour repart à chaque dizaine, avec les trois notes déjà jouées toutes les 10 répétitions.
- **Objectif de la série** : une pastille par dizaine sous le nombre ; quand l'objectif ne tombe pas sur une dizaine, sa case est cerclée d'un filet de la couleur des segments allumés, intérieur éteint. Objectif atteint : le cadran passe au vert.
- **Intérieur : la jauge du mouvement capté en direct**, pâle avant la validation (3 répétitions).
- **Récupération** : un segment par tranche de 15 s (avec le bip), jusqu'au repos prévu, puis vert. Jamais une trotteuse de 60 s : le cadran n'est pas une horloge.
- Un bloc ou des jours ne se représentent jamais sur le cadran : c'est une **frise** (3 semaines de progression, 1 semaine allégée, le test). Une jauge d'intensité en demi-cercle est permise (Coaching) ; elle ne doit pas ressembler au cadran de comptage.

## 5. L'intensité, une seule échelle de couleur

Bleu (calme) → ambre (soutenu) → rouge (maximal), en dégradé. Calme : semaine allégée, séance légère. Soutenu : progression. Maximal : jour de test. Vert : objectif ou cible atteints (✓, ⚑). Une tendance (▲ = ▼) n'est pas une atteinte : elle reste en couleur de texte. Les alertes (semaine refaite, test à faire, Forme basse) ne prennent pas de couleur : elles portent le symbole « ! ». L'orange n'est plus une couleur d'alerte.

## 6. Expliquer une fois, au moment utile

Un nouvel élément (point d'état, frise, bloc) s'explique une seule fois, à son premier affichage, par une bulle ou une fiche courte avec « Compris ». Ensuite, sur demande seulement, sous (i). Jamais pendant une série.

## 7. Textes

Des étiquettes, pas des phrases. Pendant l'effort, 5 ou 6 mots au plus. Chiffres réels plutôt qu'adjectifs (« Forme 91 % × 2 · fatigue 2/5 »).

## 8. Honnêteté des données

- Chaque calcul reprend une méthode publiée, citée dans le code et dans le (i). Pas de méthode inventée.
- Ce qui est un choix de l'app (rythme 3 + 1, test toutes les 4 semaines, règle du jour de repos) est présenté comme tel.
- L'« attendu » est le rythme nécessaire pour atteindre l'objectif à la date choisie, pas une prédiction.
- Sans confiance suffisante, un état « en cours » (« 5 / 8 séances ») plutôt qu'un chiffre.
- « Gain réel », « en avance », « en retard » seulement au-delà de la variation habituelle (Hopkins). Un cycle sans gain le dit.

## 9. Graphiques et symboles plutôt que texte

Un graphique par question. Les chiffres ne sont que l'étiquette de la valeur clé d'un graphique. Pas de pile clé-valeur ni de tableau de chiffres là où une barre, une courbe ou une jauge suffit. Symboles, légende donnée une fois : ⌖ objectif · ◆ test · ✓ atteint · ← en cours · ● fait · ○ prévu · ! alerte · ★ record · ▲▼ tendance · ◷ repos · ✎ modifier · ⋯ menu. Le texte est réservé aux exceptions.

Un symbole répété ne sert de compteur que si son nombre reste petit et borné (5 au plus) ; au-delà, un nombre ou un graphique.

Une légende ne montre que ce qui est dessiné : un élément absent du graphique (pas de date d'objectif, donc pas de ligne attendue) n'apparaît pas dans sa légende.

Maquette de référence : https://claude.ai/artifact/LHFCQ3zEWvjMoKSJFaXVJJ

## 10. Le temps se lit sur une frise, pas dans une liste

Des événements datés (séances, séries, tests) se placent sur un axe de temps, jamais dans une liste de lignes de texte. Le motif de référence est le **journal** de l'historique :

- **Deux axes** : une ligne par jour, aujourd'hui en haut, on fait défiler pour remonter ; en abscisse l'heure du jour, le matin à gauche, le soir à droite. La plage (début, fin) se règle dans les Réglages, 06:00 → 23:00 par défaut, 6 h au moins, graduée toutes les 3 h.
- **Une séance = sa silhouette**, posée à son heure : une barre fine par série, hauteur proportionnelle aux répétitions, verte si la cible de la série est atteinte. Plusieurs séances dans la journée tiennent sur la même ligne : c'est le but.
- **Symboles** : ★ record ; Σ total du jour à droite ; ligne pointillée = jour sans séance (jamais « manqué » : il n'y a pas de jours prévus) ; < > = séance hors de la plage, posée au bord, jamais masquée.
- **Lisibilité des lignes** : deux nuances alternées (environ 5 % en thème sombre, 7 % en thème clair) ; aujourd'hui teinté de la couleur principale (environ 12 %) ; un filet plein sous chaque lundi pour séparer les semaines.
- **Gestes** : la ligne du jour (44 pt) se touche en entière : une séance, on pousse son détail ; plusieurs, un menu les liste (heure et total) ; appui long, supprimer une séance.
- **Accessibilité** : une étiquette par jour qui résume ses séances et son total.

La même logique vaut ailleurs : une frise verticale datée pour le plan (une ligne par semaine, son but, ses dates), une frise horaire pour la journée. Chaque échelle de temps a sa frise, et chacune apparaît là où l'on regarde à cette fréquence (voir section 1).

## 11. Conformité Apple (HIG)

**Deux mondes.** Le compteur est immersif, comme l'app Exercice de la Watch : le thème choisi, plein écran, barre d'état masquée pendant une série seulement. Tout le reste ressemble à Santé : Coaching, Historique, Réglages, fiches et (i). Ces écrans suivent le mode clair ou sombre du système, jamais le thème.

**Navigation.** Un seul écran : le cadran. Coaching et Historique s'ouvrent en feuilles, chacune dans un `NavigationStack` :
- `navigationTitle` en grand titre, pas de titre fait main en capitales ;
- bouton de fermeture dans la `toolbar` ;
- le détail s'ouvre en poussant une page, avec le retour par glissement.

**Couleurs.** Hors compteur, on utilise les couleurs sémantiques :
- fond `systemGroupedBackground`, cartes `secondarySystemGroupedBackground` ;
- texte `label` et `secondaryLabel`, filets `separator`.

L'échelle d'intensité (§ 5) et le vert « atteint » existent en version claire et en version sombre, avec un contraste d'au moins 3:1 pour les tracés et 4,5:1 pour le texte.

**Cartes façon Santé.**
- En-tête : un SF Symbol et un libellé dans la couleur du domaine, la date à droite.
- Corps : un gros chiffre en SF Rounded, l'unité en petit, puis le graphique.
- Si la carte s'ouvre : un chevron, et toute la carte réagit au toucher.

**Texte.**
- Styles Dynamic Type (`.largeTitle` … `.caption2`), avec le design `.rounded`. Aucune taille fixe.
- `@ScaledMetric` pour les dimensions qui suivent le texte.
- Le cadran garde un chiffre calculé sur sa taille, mais ses libellés suivent Dynamic Type.
- On vérifie chaque écran en taille AX3 : rien de tronqué, et on passe en disposition verticale si besoin.

**Symboles (§ 9 en SF Symbols).**

| Avant | SF Symbol |
|---|---|
| ⌖ | `scope` |
| ◆ | `diamond.fill` |
| ✓ | `checkmark` |
| ● | `circle.fill` |
| ○ | `circle` |
| ! | `exclamationmark.circle` |
| ★ | `star.fill` |
| ▲▼ | `arrowtriangle.up.fill` / `arrowtriangle.down.fill` |
| ◷ | `timer` |
| ✎ | `pencil` |
| ⋯ | `ellipsis` |
| ⚑ | `flag.fill` |
| < > | `chevron.left` / `chevron.right` |

Σ reste un caractère, faute d'équivalent. Aucun caractère Unicode ne sert d'icône.

**Toucher.** Toute zone touchable mesure au moins 44 × 44 pt, avec `contentShape` si le dessin est plus petit.

**Graphiques.**
- Swift Charts partout sauf sur le cadran (`CounterDial`, qui reste un dessin propre à l'app).
- Sélection au doigt par une règle verticale, et Audio Graphs pour VoiceOver.
- Pas de sélection au doigt sur un graphique posé dans une carte qui s'ouvre : toucher la carte ouvre son détail, la sélection se fait dans le détail. La sélection n'existe que sur un graphique qui n'ouvre rien (page de détail, Chemin).

**Explications (§ 6).** Les bulles « Compris » utilisent TipKit.

**Accessibilité.**
- Chaque élément porte un libellé VoiceOver qui dit la valeur, pas le symbole.
- Les animations respectent « Réduire les animations ».
- Les retours haptiques passent par `.sensoryFeedback`.

## 12. Typographie et espace

Les biais de design d'un assistant IA sont connus : trop de texte, des caractères trop petits, une
mise en page serrée, des tailles choisies au cas par cas. Ces règles les corrigent ; elles priment
sur l'habitude.

- **5 tailles, pas une de plus** (`AppTheme.textStyle`, toutes en Dynamic Type) : chiffre clé
  34 (`largeTitle`), titre 22 (`title2`), texte 17 (`body`), secondaire 15 (`subheadline`),
  note 13 (`footnote`). **Jamais sous 13 pt.** Le texte qu'on lit est à 17 ; 13 ne sert qu'aux
  libellés d'un graphique ou d'une frise.
- **Une carte, une idée** : en tête, l'information principale en titre (22) ; dessous, une phrase
  au plus en texte (17) ; le reste se lit sur une page de détail, en touchant la carte.
- **Une phrase, pas un paragraphe** : une raison tient en moins de dix mots (« Test 1 sur 2 : ton
  niveau de départ. »). Si elle n'apporte rien de neuf, on ne l'écrit pas.
- **Le texte long est optionnel** : l'explication complète (le pourquoi, les sources, les règles)
  est permise, mais seulement dans une vue qu'on ouvre exprès : « En savoir plus » sous la phrase,
  page de détail, (i). Elle n'est jamais sur l'écran principal.
- **De l'air** : marge intérieure des cartes 20 pt, 20 pt entre les cartes, 16 pt entre les
  éléments d'une carte ; une ligne touchable fait 44 pt au moins.
- **Le chiffre avant les mots** : quand une donnée se montre (frise, barre, chiffre), on ne la
  répète pas en phrase.

