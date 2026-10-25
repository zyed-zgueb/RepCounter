# Reps — compteur de répétitions automatique

App iOS (SwiftUI, iOS 16+, iPhone). Tu poses le téléphone, tu fais tes répétitions :
le compteur s'affiche à la 3e et continue seul, avec annonce vocale de chaque nombre.
Aucun réglage, aucun exercice à choisir.

## Lancer
1. Ouvrir `RepCounter.xcodeproj` dans Xcode 15 ou plus récent.
2. Cible RepCounter → Signing & Capabilities : choisir ton Team et remplacer le
   Bundle Identifier `com.example.RepCounter` par un identifiant unique.
3. Brancher l'iPhone et lancer (⌘R). Il faut un vrai iPhone (caméra TrueDepth).

## Placement
- Pompes : téléphone posé au sol, écran vers le haut, sous ta tête.
- Abdos : téléphone tenu contre la poitrine.
- Autres exercices : téléphone posé face à toi, corps entier dans le cadre.

Touche l'écran pour remettre à zéro. Après une pause, la série suivante s'ajoute au total.

## Retour sonore
Le bouton en haut à droite choisit la fréquence des annonces vocales : **chaque rep**,
**toutes les 5** ou **toutes les 10**. Les répétitions non annoncées font un bip court.
Le premier nombre est toujours dit (le comptage a démarré) et une pause est annoncée
avec le total (« Pause. Total : 18 »). Le son fonctionne en mode silencieux et se mélange
à la musique. Le réglage est mémorisé.

## Comment ça marche
- **Mesures en parallèle** (`SensorHub`) : profondeur TrueDepth, image réduite 12×16,
  visage, squelette Vision, gravité (CoreMotion).
- **Un suiveur par source** (`SignalTracker`) : ACP glissante → signal 1D → cycles détectés
  par hystérésis à seuils adaptatifs (percentiles 5/95 sur 10 s).
- **Verrouillage** (`AutoCounter`) : la première source qui montre 3 cycles réguliers devient
  la référence. Régulier = périodes cohérentes, signal semblable à lui-même à une période
  d'écart, opposé à une demi-période, et fluide. Le bruit et les manipulations du
  téléphone échouent à ces tests.
- Au verrouillage, les 3 cycles sont comptés, plus ceux manqués pendant la mise en place.
- Plus de cycle pendant environ 3 périodes : pause, la source sera recherchée à nouveau.

## Validation
Logique testée en simulation (capteurs synthétiques, 5 tirages aléatoires par scénario).
`Simulation/simulate_counter.py` reproduit `AutoCounter.swift` en Python (numpy) ; à relancer
après toute modification du compteur, en gardant les deux en phase :

    python3 Simulation/simulate_counter.py --seeds 5


| Scénario | Résultat |
|---|---|
| Pompes 15, après 3 s de mise en place | 15/15 sur 5 tirages |
| Pompes rapides 20 (1 s) | 20/20 sur 5 tirages |
| Abdos 12, téléphone sur la poitrine, après manipulation | 12/12 sur 5 tirages |
| Abdos lents 8 (4 s par rep) | 8/8 sur 5 tirages |
| 2 séries (10 + pause 15 s + 8) | 18/18 sur 5 tirages |
| Téléphone posé, personne, 60 s | 0 |
| Allongé immobile en respirant, téléphone sur la poitrine | 0 |
| Téléphone manipulé 20 s | 0 |

Le code Swift n'a pas été compilé (préparé sans Xcode).
