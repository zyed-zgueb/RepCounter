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
- Au verrouillage, les 3 cycles sont comptés, plus ceux faits avant : cycles déjà détectés
  au même rythme et avec une amplitude comparable (un rythme humain irrégulier retarde la
  note de régularité), puis ceux manqués pendant la mise en place.
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
| Abdos — 15 petits abdos rapides (6°) juste après manipulation, puis essoufflement | 14 à chaque tirage (−1) |
| Abdos — 20 petits abdos très rapides · 2 séries de 10 séparées par 20 s d'essoufflement | exact à chaque tirage |
| Squats — 10 squats · Biceps — 12 flexions | exact à chaque tirage |

Faux départs : 0 sur 100 séances sans exercice (téléphone posé, allongé en respirant, debout
immobile, téléphone manipulé, allongé essoufflé en profil Abdos ; 20 tirages chacun).

Limite connue : la première répétition qui suit immédiatement une manipulation du téléphone
peut être manquée. Le profil Développé épaules n'est pas simulé. Le code Swift n'a pas été
compilé (préparé sans Xcode).
