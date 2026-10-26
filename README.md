# Reps — compteur de répétitions

App iOS (SwiftUI, iOS 16+, iPhone). Tu choisis l'exercice sur l'accueil, tu places le
téléphone comme indiqué, tu fais tes répétitions : le compteur s'affiche à la 3e et
continue seul, avec annonce vocale.

## Écrans
- **Accueil** : une carte par exercice (avec le placement du téléphone) et le réglage des
  annonces vocales. La caméra est éteinte.
- **Séance** : pas de vidéo. L'anneau et le grand chiffre, comme sur l'icône ; en dessous,
  la courbe en direct de ce que capte l'app et une pastille : « J'attends ton mouvement »,
  « Mouvement trop léger » (orange) ou « Je te capte » (bleu, avec un halo). La croix
  revient à l'accueil ; toucher l'écran remet à zéro.
- La caméra ne s'allume que pour les exercices qui en ont besoin (Pompes, Autre exercice).
  Abdos, squats, biceps et développé n'utilisent que les capteurs de mouvement.

## Lancer
1. Ouvrir `RepCounter.xcodeproj` dans Xcode 15 ou plus récent.
2. Cible RepCounter → Signing & Capabilities : choisir ton Team et remplacer le
   Bundle Identifier `com.example.RepCounter` par un identifiant unique.
3. Brancher l'iPhone et lancer (⌘R). Il faut un vrai iPhone (caméra TrueDepth).

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
Pendant la séance, le bouton tracé de pouls affiche ce que voit l'app : mesures par seconde
(en orange sous 20) et, pour chaque capteur, l'amplitude du mouvement par rapport au seuil
(il faut ≥ 100 %), les cycles détectés et la note de régularité (il faut ≥ 0,60 pour que le
compteur démarre). Une capture de cet écran pendant un exercice qui ne compte pas suffit
à comprendre pourquoi.

Touche l'écran pour remettre à zéro. Après une pause, la série suivante s'ajoute au total.

## Enregistrer une séance pour l'analyser
Pendant une séance, le bouton ● enregistre les mesures des capteurs (pas de vidéo : l'image
se limite à la vignette 12×16 du compteur ; ~3 Mo par minute, 5 minutes au plus). Les 16 s
qui précèdent l'appui sont incluses, pour que la relecture reproduise exactement l'app ; la
répartition des distances mesurées par TrueDepth est aussi enregistrée pour l'analyse. À l'arrêt,
l'app demande combien de répétitions ont réellement été faites, puis propose de partager le
fichier (AirDrop, Mail…). Il est aussi visible dans Fichiers › Sur mon iPhone › Reps ›
Recordings. Déposé dans `Recordings/`, il se rejoue avec `Simulation/replay.py`, qui compare
les comptes (réel, app, compteur Python) et trace le signal de chaque capteur.

## Retour sonore
L'accueil (et le bouton haut-parleur de la séance) choisit la fréquence des annonces vocales : **chaque rep**,
**toutes les 5** ou **toutes les 10**. Les répétitions non annoncées font un bip court.
Le premier nombre est toujours dit (le comptage a démarré) et une pause est annoncée
avec le total (« Pause. Total : 18 »). Le son fonctionne en mode silencieux et se mélange
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

La séance de 14:14 confirme que l'app et le compteur Python donnent le même résultat sur
données réelles. Profondeur brute : le 10e centile des distances suit la partie du corps la
plus proche (0,58 m en haut de pompe → 0,16 m en bas, puis non mesurable ~0,25 s). Utilisé
comme mesure, il compte aussi 10/10 ; à confirmer sur d'autres séances avant d'en changer. Le code Swift n'a pas été
compilé (préparé sans Xcode).
