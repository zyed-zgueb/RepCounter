# Reps — compteur de répétitions

App iOS (SwiftUI, iOS 16+, iPhone). Tu choisis l'exercice sur l'accueil, tu places le
téléphone comme indiqué, tu fais tes répétitions : le compteur s'affiche à la 3e et
continue seul, avec annonce vocale.

## Écrans
Style « moniteur » : fond quasi noir, panneaux à liseré fin, chiffres à chasse fixe, voyants
d'état, tracé du signal façon électrocardiogramme.

Principe : à l'écran, seulement ce qui sert pendant l'effort ; le reste est rangé dans les
Réglages. Pas de défilement, sauf pour une liste qui dépasse l'écran.

- **Accueil** : la liste des exercices (placement du téléphone, capteur utilisé) et une roue
  dentée. La caméra est éteinte.
- **Réglages** (roue dentée) : annonce vocale, thème, mode analyse.
- **Séance** :
  1. **Veille** : les capteurs tournent (le tracé et le voyant « Signal OK » aident à se
     placer), mais rien ne compte.
  2. **Démarrer** : 5 s de mise en place, compte à rebours vocal (« 3, 2, 1, c'est parti »).
     Tout ce qui précède est ignoré.
  3. **Séries automatiques** : le compteur de la série s'affiche à la 3e répétition (les
     premières sont rattrapées). Quand tu t'arrêtes ~4 s, la série est close (« Série 2 : 12.
     Récupération. ») et un chronomètre de récupération s'affiche, annoncé toutes les 30 s.
     La série suivante démarre dès que tu reprends, sans toucher l'écran.
  4. **Annuler série** : annule la série en cours (ou la dernière, pendant la récupération).
  5. **Terminer** : résumé de la séance (total, durée, séries, moyenne, cadence, détail par
     série) ; « Nouvelle séance » ou « Quitter ».
- Tableau de bord pendant la séance : total, nombre de séries, cadence (s/rep), tracé du
  signal, journal des séries sur une ligne fixe (les 4 dernières, les plus anciennes résumées
  par « +N » ; le détail complet est dans le résumé).
- **Mode analyse** (Réglages) : ajoute à la séance l'enregistrement ●, le diagnostic des
  capteurs et la régularité du signal. Désactivé par défaut.
- **Répétitions détectées, pas encore validées** : avant le démarrage du comptage d'une
  série, le cadran suit déjà le mouvement (graduations pâles), affiche les répétitions
  détectées en chiffres pâles « à valider », trois témoins de validation (« Détection 2/3 »),
  une onde et une vibration légère à chaque détection. Une fois validé, tout passe en plein.

## Thèmes
Les thèmes sont des données : `RepCounter/Themes.json` (couleurs, police, arrondis, lueur,
clair/sombre, gratuit ou premium), choisis dans les Réglages. Aucun écran n'a de couleur en dur : tout passe par
`@Environment(\.theme)` (`Theme.swift`). Ajouter un thème = ajouter une entrée au fichier.
`ThemeStore` mémorise le choix et prévoit le déblocage des thèmes premium par achat intégré
(StoreKit à brancher ; en attendant, tous les thèmes sont utilisables). Thèmes livrés :
Moniteur (gratuit), Phosphore, Clinique (clair), Néon.

## Maquettes
`Design/mockups/` reproduit les écrans en HTML à partir du même `Themes.json`, pour valider
le rendu sans Mac : `node Design/mockups/render.js` → `Design/mockups/out/*.png`. Polices
approchées (JetBrains Mono ≈ SF Mono, Inter ≈ SF Pro), pictogrammes à la place des SF Symbols.
- La caméra ne s'allume que pour les exercices qui en ont besoin (Pompes, Autre exercice).

## Exercices
Chaque exercice fixe les capteurs écoutés.

| Exercice | Téléphone | Capteurs |
|---|---|---|
| Autre exercice | posé face à toi, ou porté | tous, le plus régulier l'emporte |
| Pompes | au sol, écran vers le haut, sous ta tête | profondeur, visage, image |
| Abdos | à plat contre la poitrine | gyroscope (vitesse de rotation) |
| Squats | à la main ou contre la poitrine | accélération verticale, inclinaison |
| Biceps | dans la main qui travaille | inclinaison, gyroscope |
| Développé épaules | brassard sur l'avant-bras qui pousse | accélération verticale, inclinaison |

Abdos : le gyroscope mesure la vitesse de rotation. Un petit basculement rapide des
épaules (4 à 6°) y est environ 7 fois plus fort qu'une respiration de même angle, ce que
l'inclinaison seule ne distingue pas. Les répétitions de plus de 3 s ne sont pas comptées
(ce serait la respiration).

En série, un cycle plus faible que 40 % des répétitions précédentes ne compte pas ; deux de
suite marquent la fin de la série. Ça évite de compter l'essoufflement après des abdos.

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
Les Réglages choisissent la fréquence des annonces vocales : **chaque rep**,
**toutes les 5** ou **toutes les 10**. Les répétitions non annoncées font un bip court.
Le premier nombre d'une série est toujours dit (le comptage a démarré) ; la fin de série
est annoncée avec son nombre de répétitions, puis la récupération toutes les 30 s. Le son fonctionne en mode silencieux et se mélange
à la musique. Le réglage est mémorisé.

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

Abdos du 14:19 : le 20e avait été compté 2,7 s en retard, par le mouvement de fin (retour au
sol trop lent pour le gyroscope). Rejoué avec la règle du retour non vu : compté 1,1 s après
la montée, et le mouvement de fin n'ajoute rien.

La séance de 14:14 confirme que l'app et le compteur Python donnent le même résultat sur
données réelles. Profondeur brute : le 10e centile des distances suit la partie du corps la
plus proche (0,58 m en haut de pompe → 0,16 m en bas, puis non mesurable ~0,25 s). Utilisé
comme mesure, il compte aussi 10/10 ; à confirmer sur d'autres séances avant d'en changer. Le code Swift n'a pas été
compilé (préparé sans Xcode).
