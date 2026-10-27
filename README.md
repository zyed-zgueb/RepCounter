# Reps — compteur de répétitions

App iOS (SwiftUI, iOS 17+, iPhone). L'app s'ouvre sur le cadran, réglé sur ton dernier
exercice. Tu places le téléphone comme indiqué, tu touches Démarrer et tu fais tes répétitions :
le compteur s'affiche à la 3e et continue seul, avec un retour sonore bref et feutré.

## Écran
Un seul écran : le cadran (60 graduations), éclairé par un halo de la couleur de l'état —
bleu pendant l'effort, orange au repos, vert à la fin. Style « moniteur » : fond quasi noir,
chiffres à chasse fixe, voyants d'état, tracé du signal façon électrocardiogramme apaisé (lissé, lent, plat quand rien ne bouge).

Principe : à l'écran, seulement ce qui sert à l'instant ; le reste est rangé dans les
Réglages. Pas de défilement.

1. **Veille** (ouverture de l'app) : au centre du cadran, le pictogramme et le nom de
   l'exercice. **On glisse à gauche ou à droite pour changer d'exercice**, comme les cadrans
   d'une montre : le contenu défile dans le cadran, qui ne bouge pas, avec un cran de vibration ;
   des points indiquent la position parmi **Mes exercices** (choisis et ordonnés dans les
   Réglages ; par défaut Pompes, Abdos, Squats, Fentes, Tractions) ; aux deux bouts, le contenu résiste.
   Un toucher esquisse le geste. Les capteurs du nouvel exercice démarrent une fois le geste
   posé (0,4 s), et l'app retient le dernier choisi. Le cadran suit déjà le mouvement capté ;
   en dessous, la consigne de placement, le tracé du mouvement capté, avec un voyant devant le nom du capteur (gris au repos, bleu pour un léger mouvement, vert quand il est assez net pour compter) et **Démarrer**.
   Roue dentée : les Réglages. Rien ne compte.
2. **Départ** : 5 s pour se mettre en position, le cadran se remplit ; une note à 3, 2 et 1,
   un accord au départ. Tout ce qui précède est ignoré.
3. **Série** : il ne reste que le nombre, en très grand, et une ligne discrète (total de la
   séance). Avant la validation (3 répétitions), le cadran montre les répétitions
   détectées en pâle « à valider », trois témoins, une onde et une vibration légère à chacune ;
   puis tout passe en plein (les premières sont rattrapées).
4. **Récupération** : quand tu t'arrêtes ~4 s, la série est close et le cadran devient un
   chronomètre orange, avec les dernières séries sur une ligne fixe (« +N » pour les plus
   anciennes). La série suivante démarre dès que tu reprends, sans toucher l'écran.
5. **Annuler série** annule la série en cours (ou la dernière, pendant la récupération).
   **Terminer se maintient** 0,8 s (une jauge se remplit) : pas de fin de séance par erreur.
6. **Fin** : le total dans le cadran, l'écart avec la séance précédente (« ▲ +6 vs jeudi 22 »)
   et le record battu, l'histogramme des séries (étoile sur la série record), puis trois mesures :
   score d'endurance, forme, durée. Tant qu'une mesure n'est pas calculable, son état
   « en cours » la remplace (« 2 / 3 séries », « réf. 2 / 3 »). **Toucher une série
   permet de corriger son compte** (− / +, avec le compte d'origine). Puis « Nouvelle séance ».

- **Historique** (icône graphique, en veille et à la fin) : Σ (tous les exercices) ou un
  exercice pratiqué, puis quatre blocs, une place pour chaque chose :
  1. **Conseil**, seulement quand il y a lieu ;
  2. **Score d'endurance** et **Forme**, deux tuiles côte à côte (valeur, mini-courbe ; ou leur
     état « en cours ») — une touche ouvre le détail (jauge et (i), courbe de forme) ;
  3. **Activité** : la semaine en cours (cadran, écart avec la semaine précédente, séances,
     temps, semaines d'affilée) et la régularité sur 16 semaines — une touche ouvre le volume
     sur 12 semaines ;
  4. **Records** (série, séance, semaine ; en orange quand ils datent de la semaine) et la
     liste des **séances**. Une séance s'ouvre sur son détail : séries, cadence, récupérations
     et rythme rep par rep ; un appui long la supprime.
- **Réglages** (roue dentée, en veille et à la fin) : mes exercices (− / + et poignée ≡ pour
  l'ordre ; il en reste toujours un) et « J'ai un brassard », profil, retour sonore, thème, mode analyse.
- **Mode analyse** : ajoute à la séance l'enregistrement ●, le diagnostic des capteurs et
  la régularité du signal. Désactivé par défaut.

## Historique
Chaque séance terminée est enregistrée sur l'iPhone (SwiftData, `History.swift`) avec ses séries
et l'instant de chaque répétition : toute statistique future pourra être calculée sur les
séances passées. Le modèle suit les règles de CloudKit (valeurs par défaut, relations
optionnelles) : la synchronisation iCloud pourra être activée sans migration. Les statistiques
sont calculées dans `HistoryStats`, les écrans sont dans `HistoryView.swift`.

## Forme
Par séance, à partir de la vitesse des répétitions (instant de chaque répétition) :
la **vitesse** (durée médiane d'une répétition de la première série) et le **maintien** de
cette vitesse (durée des 3 dernières répétitions ÷ celle des 3 premières, en moyenne sur les
séries d'au moins 6 répétitions), comparés à la référence personnelle (médianes des 10
dernières séances de l'exercice) :
**Forme = 100 × √((vitesse habituelle ÷ vitesse du jour) × (ralentissement habituel ÷ ralentissement du jour))**.
100 % = comme d'habitude ; fatigué ou en forme au-delà de la variation normale (1,5 fois
l'écart-type des formes des séances de référence, au moins 3 %). Il faut 3 séances précédentes
pour établir la référence. Principe : l'entraînement basé sur la vitesse (la vitesse et sa perte
au fil d'une série reflètent la fatigue). Affichée en fin de séance, dans le détail d'une séance
et dans le panneau Forme de l'historique (`Form.swift`).

## Conseil
En tête de l'historique d'un exercice, au plus un conseil, le plus important d'abord
(`Advice.swift`) : **signal de fatigue** (séance dans la zone fatiguée depuis moins de 3 jours, ou score
d'endurance en baisse 2 séances de suite sans baisse de volume), **pic de charge** (volume de la
semaine > 1,5 × la moyenne des 4 précédentes), **plateau** (3 séances notées en 3 semaines sans
dépasser le meilleur score d'avant), **record à portée** (une série récente à 1 ou 2 répétitions
du record de série).

## Score d'endurance
Score d'endurance musculaire, par séance d'au moins 3 séries : **r₁ + r₂·k(R₂) + r₃·k(R₃)**, les répétitions des 3 premières
séries, chacune pondérée par le repos R qui la précède, **k(R) = (60 s / R)^0,2** (1 avec 60 s,
1,15 avec 30 s, 0,80 avec 3 min ; R borné entre 15 s et 5 min). Pour Biceps et Développé, on
multiplie par la charge totale soulevée : l'équipement (1 haltère, 2 haltères ou barre) et le poids (par haltère, ou de la barre) se règlent sous le cadran, mémorisés par exercice ; « 2 × 5 kg » donne 10 kg. L'indice
récompense la capacité, le maintien d'une série à l'autre et la récupération rapide ; le format
commun (3 séries) le rend comparable d'une séance et d'une personne à l'autre. L'indice d'un
exercice est sa meilleure séance des 4 dernières semaines.

| Séance (pompes) | Séries | Repos | Indice |
|---|---|---|---|
| Régulière | 14 · 13 · 12 | 60 s | 39 |
| S'effondre | 14 · 10 · 8 | 60 s | 32 |
| Repos court | 14 · 12 · 11 | 30 s | 40 |
| Repos très long | 14 · 14 · 14 | 3 min | 36 |

**Jauge** (historique d'un exercice) : un arc de graduations. Pour les pompes, avec l'âge et le
sexe (Réglages › Profil, facultatif), l'arc est découpé en cinq niveaux selon le barème du test de
pompes de la SCPE/CSEP, repris par l'ACSM (meilleure série des 4 dernières semaines) ; pour les
autres exercices, il se remplit jusqu'au record. Le (i) explique le calcul, la physiologie (récupération
de la phosphocréatine) et les limites (`Endurance.swift`, `EnduranceView.swift`).

L'exposant 0,2 compense à peu près la baisse de répétitions qu'entraîne un repos plus court :
point de départ, à caler sur des séances réelles.

## Thèmes
Les thèmes sont des données : `RepCounter/Themes.json` (couleurs, police, arrondis, lueur,
clair/sombre, gratuit ou premium), choisis dans les Réglages. Aucun écran n'a de couleur en dur : tout passe par
`@Environment(\.theme)` (`Theme.swift`). Ajouter un thème = ajouter une entrée au fichier.
`ThemeStore` mémorise le choix et prévoit le déblocage des thèmes premium par achat intégré
(StoreKit à brancher ; en attendant, tous les thèmes sont utilisables). Thèmes livrés :
Moniteur (gratuit), Phosphore, Clinique (clair), Néon.

## Pictogrammes
Dix pictogrammes dessinés (`ExerciseIcon.swift`), sur un squelette unique : tronc, cou, tête,
bras, avant-bras, cuisse et tibia ont des longueurs fixes, chaque exercice n'est qu'une pose ;
les proportions sont donc justes et identiques partout. Trait 1,2 (repère 20 × 20). Le matériel
(barres, banc, haltères, sol) prend la couleur de la silhouette, atténuée à 40 %. Prototype et
comparaisons : `Design/icon/pictogrammes.html`.

## Maquettes
`Design/mockups/` reproduit les écrans en HTML à partir du même `Themes.json`, pour valider
le rendu sans Mac : `node Design/mockups/render.js` → `Design/mockups/out/*.png`. Polices
approchées (JetBrains Mono ≈ SF Mono, Inter ≈ SF Pro), pictogrammes approchant les SF Symbols.

## Projet Xcode
`RepCounter.xcodeproj` est généré : après l'ajout ou le retrait d'un fichier Swift, ajouter
son nom dans `Tools/gen_xcodeproj.py` puis `python3 Tools/gen_xcodeproj.py`.

Les réglages propres à chaque Mac (équipe de signature, identifiant de l'app) ne sont pas dans
le fichier projet mais dans `Config/Local.xcconfig`, non versionné (modèle :
`Config/Local.xcconfig.example`), inclus par `Config/Base.xcconfig`. Ainsi Xcode ne modifie pas
le fichier projet et un pull n'entre jamais en conflit. Ne pas régler l'équipe dans
Signing & Capabilities.
- La caméra ne s'allume que pour les exercices qui en ont besoin (Pompes, Autre exercice).

## Exercices
Chaque exercice fixe les capteurs écoutés.

| Exercice | Téléphone | Capteurs |
|---|---|---|
| Autre exercice | posé face à toi, ou porté | tous, le plus régulier l'emporte |
| Pompes | au sol, écran vers le haut, au niveau de la tête | profondeur, visage, image |
| Abdos | à plat contre la poitrine | gyroscope (vitesse de rotation) |
| Squats | à la main ou contre la poitrine | accélération verticale, inclinaison |
| Biceps | posé face à toi à 2 m (sans brassard) · brassard sur l'avant-bras | squelette, image (+ mouvement) · inclinaison, gyroscope |
| Développé épaules | posé face à toi à 2 m (sans brassard) · brassard sur l'avant-bras | squelette, image (+ mouvement) · accélération verticale, inclinaison |
| Fentes | à la main ou contre la poitrine | accélération verticale, inclinaison |
| Tractions | poche de pantalon ajustée | accélération verticale, inclinaison |
| Dips | poche de pantalon ajustée | accélération verticale, inclinaison |
| Rowing haltère | posé sur le côté à 2 m, toi de profil (sans brassard) · brassard sur l'avant-bras | squelette, image (+ mouvement) · inclinaison, gyroscope |

**Brassard** (Réglages › Mes exercices › « J'ai un brassard », désactivé par défaut) : la plupart
des gens n'en ont pas, alors biceps, développé et rowing se comptent par défaut à la caméra,
iPhone posé (squelette Vision ; la profondeur TrueDepth ne porte pas à 2 m). Les capteurs de
mouvement restent à l'écoute si l'iPhone est malgré tout porté au bras. Avec un brassard
déclaré, ces exercices se comptent comme avant aux capteurs de mouvement seuls : plus précis,
sans caméra (ni batterie ni autorisation). Le réglage change la consigne sous le cadran.

Fentes, tractions, dips et rowing reprennent des profils déjà validés (squats pour les trois
premiers, biceps pour le rowing) ; ils restent à vérifier sur des enregistrements réels.

Abdos : le gyroscope mesure la vitesse de rotation. Un petit basculement rapide des
épaules (4 à 6°) y est environ 7 fois plus fort qu'une respiration de même angle, ce que
l'inclinaison seule ne distingue pas. Les répétitions de plus de 3 s ne sont pas comptées
(ce serait la respiration).

En série, un cycle plus faible que 40 % des répétitions précédentes ne compte pas ; deux de
suite marquent la fin de la série. Ça évite de compter l'essoufflement après des abdos.
À l'inverse, un cycle 40 % plus ample que les répétitions de la série, après une pause d'au
moins 1,5 fois son rythme, est le téléphone qu'on reprend sur la poitrine : il ne compte pas et
clôt la série.

## Diagnostic
Avec le mode analyse activé (Réglages), le bouton tracé de pouls de la séance affiche ce que voit l'app : mesures par seconde
(en orange sous 20) et, pour chaque capteur, l'amplitude du mouvement par rapport au seuil
(il faut ≥ 100 %), les cycles détectés et la note de régularité (il faut ≥ 0,60 pour que le
compteur démarre). Une capture de cet écran pendant un exercice qui ne compte pas suffit
à comprendre pourquoi.

## Enregistrer une séance pour l'analyser
Avec le mode analyse activé (Réglages), le bouton ● de la séance enregistre les mesures des capteurs (pas de vidéo : l'image
se limite à la vignette 12×16 du compteur ; ~3 Mo par minute, 5 minutes au plus). Les 16 s
qui précèdent l'appui sont incluses, pour que la relecture reproduise exactement l'app ; la
répartition des distances mesurées par TrueDepth est aussi enregistrée pour l'analyse. À l'arrêt,
l'app demande combien de répétitions ont réellement été faites, puis propose de partager le
fichier (AirDrop, Mail…). Il est aussi visible dans Fichiers › Sur mon iPhone › Reps ›
Recordings. Déposé dans `Recordings/`, il se rejoue avec `Simulation/replay.py`, qui compare
les comptes (réel, app, compteur Python) et trace le signal de chaque capteur.

## Retour sonore
Pensé pour qui ne regarde pas l'écran : un son par événement, bref (moins de 0,1 s) et
feutré, en la majeur — une note par répétition, deux notes montantes tous les 5, trois tous
les 10, une note grave toutes les 30 s de récupération, deux notes descendantes en fin de série,
un arpège en fin de séance. Chaque son s'accompagne d'une vibration.

Réglages : **Sons** (par défaut), **Sons + voix** (la voix dit les paliers 5, 10, 15…, le
premier nombre d'une série, la fin de série et la durée de récupération, avec la meilleure
voix française installée — une voix Améliorée ou Premium se télécharge dans Réglages de
l'iPhone › Accessibilité › Contenu énoncé › Voix), **Silence** (vibrations seules).
Le son fonctionne en mode silencieux et se mélange à la musique.

Les sons sont synthétisés par `Design/sound/make_sounds.py` (aucun fichier source) : deux
timbres à comparer, « feutre » et « bois », avec une démo de séance pour chacun dans
`Design/sound/out/`. Le timbre `INSTALLED` est écrit dans `RepCounter/Sounds/`, embarqué
dans l'app.

    python3 Design/sound/make_sounds.py

## Comment ça marche
- **Mesures en parallèle** (`SensorHub`) : profondeur TrueDepth, image réduite 12×16,
  visage, squelette Vision, inclinaison (gravité) et accélération verticale (CoreMotion).
- **Un suiveur par source** (`SignalTracker`) : ACP glissante → signal 1D → cycles détectés
  par hystérésis à seuils adaptatifs (percentiles 5/95 sur 10 s).
- **Verrouillage** (`AutoCounter`) : la première source qui montre 3 cycles réguliers devient
  la référence. Régulier = périodes cohérentes, signal semblable à lui-même à une période
  d'écart, opposé à une demi-période, et fluide. Le bruit et les manipulations du
  téléphone échouent à ces tests.
- Au verrouillage, les 3 cycles sont comptés, plus ceux faits avant. Pendant la mise en
  place, l'axe de l'ACP et les seuils n'étaient pas encore justes : on relit alors tout
  l'historique (16 s) avec l'axe et les seuils de la série régulière, et on reprend les
  cycles qui lui ressemblent (même rythme, ampleur comparable, tracé fluide) jusqu'à une
  pause ou des secousses.
- Pompes (téléphone posé) : si le gyroscope détecte que le téléphone est manipulé,
  l'analyse repart de zéro une fois qu'il est reposé.
- Une répétition est comptée au retour à la position de repos (en haut de la pompe,
  allongé pour l'abdo…) : au démarrage du comptage, la position tenue juste avant la série
  fixe le sens du signal. Sans cela, le signe arbitraire de l'ACP pouvait faire compter à
  mi-chemin. Pour les capteurs de vitesse (gyroscope, accélération), le repos est au milieu
  du signal : le sens n'est pas modifié.
- Capteurs de vitesse : un retour lent au repos ne se voit pas (le gyroscope mesure une
  vitesse). Si le geste a eu lieu et que son retour n'arrive pas dans 1,5 période, la
  répétition est comptée ; son retour, s'il se voit plus tard, ne compte pas une seconde fois.
- Plus de cycle pendant environ 3 périodes : pause, la source sera recherchée à nouveau.

## Validation
Logique testée en simulation (capteurs synthétiques, 5 tirages aléatoires par scénario).
`Simulation/simulate_counter.py` reproduit `AutoCounter.swift` en Python (numpy) ; à relancer
après toute modification du compteur, en gardant les deux en phase :

    python3 Simulation/simulate_counter.py --seeds 5

| Scénario | Résultat (5 tirages) |
|---|---|
| Auto — pompes 15, rapides 20, 2 séries 10 + 8 | exact à chaque tirage |
| Auto — grands abdos 12 et lents 8, téléphone sur la poitrine | exact à chaque tirage |
| Auto — squats 10 et 12, téléphone à la main | exact à chaque tirage |
| Pompes — 15 pompes | 15 à chaque tirage |
| Pompes — installation lente et agitée puis 10 · puis 12 rapides | exact à chaque tirage |
| Abdos — 15 petits abdos rapides (6°) juste après manipulation, puis essoufflement | exact à chaque tirage |
| Abdos — 20 petits abdos très rapides · 2 séries de 10 séparées par 20 s d'essoufflement | exact à chaque tirage |
| Squats — 10 squats · Biceps — 12 flexions | exact à chaque tirage |

Faux départs : 0 sur 100 séances sans exercice (téléphone posé, allongé en respirant, debout
immobile, téléphone manipulé, allongé essoufflé en profil Abdos ; 20 tirages chacun).

100 séances exactes sur 100. Le profil Développé épaules n'est pas simulé.

Enregistrements réels (`Recordings/`, iPhone 14) :

| Séance | Réel | App | Rejoué |
|---|---|---|---|
| Pompes 26/10 13:02 (avant le comptage au repos) | 10 | 9 | 10 |
| Pompes 26/10 14:14 (avec pré-enregistrement et profondeur brute) | 10 | 10 | 10 |
| Abdos 26/10 14:19 (après remise à zéro) | 20 | 20 | 20 |
| Abdos 26/10 19:40 (téléphone repris sur la poitrine à la fin) | 20 | 21 | 20 |

Abdos du 14:19 : le 20e avait été compté 2,7 s en retard, par le mouvement de fin (retour au
sol trop lent pour le gyroscope). Rejoué avec la règle du retour non vu : compté 1,1 s après
la montée, et le mouvement de fin n'ajoute rien.

La séance de 14:14 confirme que l'app et le compteur Python donnent le même résultat sur
données réelles. Profondeur brute : le 10e centile des distances suit la partie du corps la
plus proche (0,58 m en haut de pompe → 0,16 m en bas, puis non mesurable ~0,25 s). Utilisé
comme mesure, il compte aussi 10/10 ; à confirmer sur d'autres séances avant d'en changer. Le code Swift n'a pas été
compilé (préparé sans Xcode).
