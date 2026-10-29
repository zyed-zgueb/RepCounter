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

Textes : des étiquettes, pas des phrases. Pendant l'effort, 5 ou 6 mots au plus ; le son, la
vibration, la couleur et le pictogramme portent le sens. Une explication n'est donnée qu'une
fois, au moment utile (première séance), ou sur demande (« ? », (i)). Les Réglages parlent
par leurs choix : une ligne seulement quand la conséquence n'est pas évidente.

0. **Premier lancement** : une page de bienvenue (« Pose ton iPhone. Entraîne-toi. Il compte. »,
   le cadran qui compte), puis rien d'autre : pas de compte, pas de questionnaire. La première
   fois qu'on démarre un exercice, la fiche **Placer ton iPhone** (une illustration, trois
   repères simples), à revoir à tout moment par **Plus de détails** au bout de la consigne, sous
   le cadran comme pendant la mise en place. L'accès à la caméra est demandé après la fiche,
   pas à l'ouverture. La première séance est commentée par trois cartes, une seule fois : la
   détection, la récupération automatique, « maintiens Terminer » (`Onboarding.swift`).
1. **Veille** (ouverture de l'app) : au centre du cadran, le pictogramme et le nom de
   l'exercice. **On glisse à gauche ou à droite pour changer d'exercice**, comme les cadrans
   d'une montre : le contenu défile dans le cadran, qui ne bouge pas, avec un cran de vibration ;
   des points indiquent la position parmi **Mes exercices** (choisis et ordonnés dans les
   Réglages ; par défaut Pompes, Abdos, Squats, Fentes, Tractions) ; aux deux bouts, le contenu résiste.
   Un toucher esquisse le geste. Les capteurs du nouvel exercice démarrent une fois le geste
   posé (0,4 s), et l'app retient le dernier choisi. Le cadran suit déjà le mouvement capté ;
   en dessous, la consigne de placement, le tracé du mouvement capté, avec un voyant devant le nom du capteur (gris au repos, bleu pour un léger mouvement, vert quand il est assez net pour compter) et **Démarrer**.
   Roue dentée : les Réglages. Rien ne compte.
2. **Mise en place** (pompes, abdos, exercices de bras à la caméra) : après Démarrer, le départ
   attend que l'iPhone et le sportif soient bien placés (`Placement.swift`). Une seule consigne à
   la fois (« Pose l'iPhone à plat », « Mets-toi en planche », « Recule d'un pas »,
   « Plus de lumière »…), sa raison, et les vérifications cochées en direct ; le cadran se
   remplit à mesure. Pour la caméra, il montre ce qu'elle voit : le squelette (jamais l'image)
   dans le cadre. Tout est bon pendant 0,8 s : vibration, puis un compte à rebours de 3 s.
   Ce qui se vérifie : l'orientation (gravité), l'immobilité (gyroscope : au sol, sur la
   poitrine qui respire, tenu), le visage (pompes), le squelette (cadrage, distance, profil),
   la luminosité. Les autres exercices (iPhone tenu, en poche, au bras) partent sur 5 s.
   Seuils réglés sur les enregistrements : `python3 Simulation/placement.py <enregistrement>`.
3. **Départ** : 5 s pour se mettre en position, le cadran se remplit ; une note à 3, 2 et 1,
   un accord au départ. Tout ce qui précède est ignoré.
4. **Série** : il ne reste que le nombre, en très grand, et une ligne discrète (total de la
   séance). Avant la validation (3 répétitions), le cadran montre les répétitions
   détectées en pâle « à valider », trois témoins, une onde et une vibration légère à chacune ;
   puis tout passe en plein (les premières sont rattrapées).
5. **Récupération** : quand tu t'arrêtes ~4 s, la série est close et le cadran devient un
   chronomètre orange, avec les dernières séries sur une ligne fixe (« +N » pour les plus
   anciennes). La série suivante démarre dès que tu reprends, sans toucher l'écran.
6. **Annuler série** annule la série en cours (ou la dernière, pendant la récupération).
   **Terminer se maintient** 0,8 s (une jauge se remplit) : pas de fin de séance par erreur.
7. **Fin** : le total dans le cadran, l'écart avec la séance précédente (« ▲ +6 vs jeudi 22 »)
   et le record battu, l'histogramme des séries (étoile sur la série record), puis trois mesures :
   score d'endurance, forme, durée. Tant qu'une mesure n'est pas calculable, son état
   « en cours » la remplace (« 2 / 3 séries », « réf. 2 / 3 »). **Toucher une série
   permet de corriger son compte** (− / +, avec le compte d'origine). Puis « Nouvelle séance ».

- **Historique** (icône graphique, en veille et à la fin) : Σ (tous les exercices) ou un
  exercice pratiqué, puis quatre blocs, une place pour chaque chose :
  1. **Phase** d'entraînement (« en cours 5 / 8 » au début) — une touche ouvre la charge et le (i) ;
  2. **Score d'endurance** et **Forme**, deux tuiles côte à côte (valeur, mini-courbe ; ou leur
     état « en cours ») — une touche ouvre le détail (jauge et (i), courbe de forme) ;
  3. **Activité** : la semaine en cours (cadran, écart avec la semaine précédente, séances,
     temps, semaines d'affilée) et la régularité sur 16 semaines — une touche ouvre le volume
     sur 12 semaines ;
  4. **Records** (série, séance, semaine ; en orange quand ils datent de la semaine) et la
     liste des **séances**, par jour (la date une fois, puis les séances à leurs heures ;
     aujourd'hui mis en avant). Une séance s'ouvre sur son détail : séries, cadence, récupérations
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
dernières séances de l'exercice qui n'étaient pas fatiguées : une baisse qui dure reste visible
au lieu de devenir la nouvelle norme) :
**Forme = 100 × √((vitesse habituelle ÷ vitesse du jour) × (ralentissement habituel ÷ ralentissement du jour))**.
100 % = comme d'habitude ; fatigué ou en forme au-delà de la variation normale (1,5 fois
l'écart-type des formes des 10 dernières séances, au moins 3 %). Il faut 3 séances précédentes
pour établir la référence. Garde-fous : les séries corrigées à la main de plus de 2 répétitions
sont écartées (découpage douteux) ; un exercice dont le comptage est juste à moins de 90 % (dès
50 répétitions) n'a ni Forme, ni phase, ni tendance (« Analyse suspendue ») : mieux vaut ne rien
afficher qu'afficher faux. Principe : l'entraînement basé sur la vitesse (la vitesse et sa perte
au fil d'une série reflètent la fatigue). Affichée en fin de séance, dans le détail d'une séance
et dans le panneau Forme de l'historique (`Form.swift`).

## Phases
En tête de l'historique d'un exercice, la phase d'entraînement : une étiquette, une action, une
couleur (`Phase.swift`, `PhaseView.swift`). La charge d'entraînement (toutes les séances) est
confrontée à la performance mesurée (la Forme de l'exercice).

| Phase | Quand | Action |
|---|---|---|
| Construction | Forme dans la variation habituelle | Continue (ou Plateau : tendance Stable ; Record à portée) |
| Surcharge | 2 séances de suite fatiguées, après une semaine plus chargée que chacune des 4 d'avant | N'augmente plus |
| Forme basse | la même baisse, sans hausse de charge | Séance légère |
| Reprise | une baisse qui commence dans les 14 jours après une pause | Monte progressivement |
| Décharge conseillée | la baisse dure depuis 14 jours | Une semaine allégée (bouton « Commencer ») |
| Décharge | 7 jours après « Commencer » | Moins de volume |
| Pause | plus de 7 jours sans séance | — |
| Rebond | après une surcharge ou une décharge, 1re séance revenue à ≥ 100 % (ou un record) dans les 14 jours | Prêt pour un record |
| Fatigue persistante | la baisse continue après une décharge ou une pause | Repos · avis médical si ça dure |

Bases : Meeusen et al. 2013 (consensus ECSS / ACSM : surcharge fonctionnelle ou non selon la
durée de la baisse, rebond après récupération ; « surentraînement » est un diagnostic médical,
jamais employé) ; Bell et al. 2023 (consensus Delphi : la décharge réduit le volume) et
Rogerson et al. 2024 (décharges de 6,4 ± 1,7 jours) ; Foster et al. 2001 (charge de séance =
effort × minutes) ; Hopkins 2000 (une mesure isolée peut être du bruit : deux séances de suite).
Le rapport charge aiguë / chronique (« Pic de charge ») est retiré : aucun effet causal démontré
(Impellizzeri et al. 2020). Durées vérifiées en texte intégral : 14 jours de baisse et 14 jours
pour chercher le rebond (Meeusen 2013 : « possible to recover from a state of OR within a 2-week
period » ; au-delà, « weeks or months to recover ») ; décharge de 7 jours (Rogerson 2024 :
6,4 ± 1,7 jours). Seul seuil **provisoire**, choix de l'app pour la confiance : 8 séances
mesurables sur 4 semaines avant d'afficher. En fin de séance, la phase ne
s'affiche qu'au passage en Rebond ou en Décharge conseillée. Le détail montre la charge des
12 dernières semaines (décharges marquées) ; le (i) explique le modèle et cite les références.

Validation : `python3 Simulation/phases.py` (miroir Python, historiques synthétiques : surcharge
puis rebond, surcharge sans rebond, surcharge qui dure, passage à vide, reprise après 3 semaines
d'arrêt, 20 progressions régulières, 20 mesures bruitées). Chaque phase attendue tombe au bon
jour (±2) ; aucune décharge conseillée ni fatigue persistante sur les historiques réguliers ou
bruités. Limite connue : avec une mesure très bruitée (4 %), « Forme basse » apparaît parfois
deux ou trois jours à tort.

## Vitesse de montée (prototype, non affichée)
Priorité 2 (répétitions en réserve, max estimé) : `Simulation/velocity.py` estime la vitesse de
montée de chaque répétition à partir de l'accélération verticale (intégrée entre deux sommets,
où la vitesse est nulle, dérive retirée), et la perte de vitesse de la série. Contrôle de
vraisemblance sur les enregistrements : la hauteur montée est sous-estimée d'un facteur 2 à 3
(tractions 14–20 cm au lieu d'~50), la cuisse basculant pendant le geste. **Pas utilisable en
l'état** : rien n'est affiché. Les équations publiées (Sánchez-Moreno 2017 pour les tractions,
Rodríguez-Rosell 2020 pour le squat chargé) ne seront appliquées qu'avec une vitesse validée
contre une référence (vidéo à 240 images/s, protocole des séries à l'échec dans
`Recordings/PROTOCOLE.md`). Pompes : la caméra TrueDepth donne la distance du visage, sans
intégration ; vitesse moyenne de montée entre 25 et 50 cm (le bas de la pompe, sous ~18 cm,
n'est pas mesurable). Sur 10 pompes : 0,86 à 0,96 m/s, 0,73 à la dernière (perte 24 %),
cohérent ; c'est la mesure la plus prometteuse, à valider sur des séries à l'échec.

## Ressenti
Deux questions facultatives d'un toucher, à partir de la 4e séance (`Feeling.swift`) :
**Fatigue ?** (item fatigue de McLean et al. 2010, figure 1 : 5 très frais, 4 frais,
3 normal, 2 plus fatigué que d'habitude, 1 toujours fatigué) sur le cadran en veille avant la première séance du jour, et **Effort ?** (0 à 10,
échelle CR-10 modifiée de Foster et al. 2001) en fin de séance. L'effort donne la charge de
séance ; une fatigue notée 1 ou 2 (sous « normal ») avec une Forme normale donne « Fatigue ressentie · surveille »
(Saw et al. 2016 : le ressenti suit la charge mieux que les mesures objectives, et les deux
concordent mal). Pas de question « Force ? » : aucun item validé trouvé. Après 5 séances de
suite sans réponse, plus de question ; Réglages › Profil › Ressenti pour les réactiver.
Foster recueille l'effort environ 30 minutes après la séance ; ici, à la fin (à 10 ou 30 minutes,
les notes ne diffèrent pas d'après Uchida et al. 2014).

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

**Tendance** (sous la courbe de la tuile, et dans le détail avec la pente par semaine) : sur les
8 dernières semaines, au moins 8 séances notées (`Progress.swift`). Pente de Theil-Sen (médiane
des pentes entre toutes les paires de séances, Sen 1968) et son intervalle de confiance à 99 %
sans hypothèse de loi (équation 2.6 de Sen, même calcul que `scipy.stats.theilslopes`).
**En progrès** : intervalle entièrement au-dessus de zéro et gain sur la période au moins égal
au plus petit changement significatif, 0,3 × l'erreur typique (Hopkins 2004 ; erreur typique =
écart-type des différences entre séances consécutives ÷ √2, Hopkins 2000). **En recul** :
l'inverse. Sinon **Stable**, qui donne aussi le conseil Plateau. Séances écartées : celles d'une
décharge, et celles dont une série a été corrigée de plus de 2 répétitions. Validation :
`python3 Simulation/progress.py` (historiques plats bruités : 0,2 % de « En progrès » à tort ;
+2 %/semaine détecté à 100 % avec 3 % de bruit, 36 % avec 8 %). La trajectoire attendue et la
projection d'un objectif de la feuille de route ne sont pas faites : aucune référence ne fixe une
courbe de progression attendue au poids du corps.

## Thèmes
Les thèmes sont des données : `RepCounter/Themes.json` (couleurs, police, arrondis, lueur,
clair/sombre), choisis dans les Réglages. Aucun écran n'a de couleur en dur : tout passe par
`@Environment(\.theme)` (`Theme.swift`). Ajouter un thème = ajouter une entrée au fichier.
`ThemeStore` mémorise le choix. Tous les thèmes sont gratuits. Thèmes livrés :
Moniteur, Phosphore, Clinique (clair), Néon.

## Soutien, note et signalement
Reps est gratuit, sans pub, sans compte, et rien ne quitte l'iPhone. Rien n'est payant.
- **Soutenir Reps** (Réglages › Reps) : cinq dons en achat intégré consommable, du petit
  merci au mécénat, qui ne débloquent rien (`Support.swift`, `TipJar.tiers`). Identifiants à
  créer dans App Store Connect : `reps.tip.thanks` (0,99 €), `reps.tip.coffee` (2,99 €),
  `reps.tip.breakfast` (5,99 €), `reps.tip.meal` (12,99 €), `reps.tip.patron` (29,99 €). Pour
  les tester dans Xcode : `Config/Dons.storekit` (les cinq consommables), à choisir dans le
  schéma (Product › Scheme › Edit Scheme › Run › Options › StoreKit Configuration).
- **Après un record**, une seule fois chacun : la demande de note App Store d'Apple dès la
  5e séance, puis, à un record suivant, une ligne discrète proposant un don dès la 10e (`Ask`).
  Jamais pendant une séance, jamais deux demandes à la fois.
- **Code source privé tant que le dépôt l'est** : `SourceCode.isPublic` (`Support.swift`) masque
  le lien « Code source », le signalement par ticket GitHub et la mention « open source » ; à
  passer à true le jour où le dépôt devient public.
- **Signaler un comptage faux** : dès qu'une série est corrigée en fin de séance, « Le compte
  était faux ? Signale-le » ouvre un ticket GitHub pré-rempli (exercice, séries comptées et
  réelles, version d'iOS). L'app n'envoie rien : l'utilisateur relit et envoie lui-même.

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

Numéro de build : à chaque compilation, `Tools/build_number.sh` inscrit le nombre de commits
(`CFBundleVersion`) et l'empreinte du commit. Le bas des Réglages affiche
`Reps 0.1 (91) · 4a6762c` ; `git show 4a6762c` retrouve le code exact (`+` : modifications
non commitées). La version (`MARKETING_VERSION`) se règle dans `Tools/gen_xcodeproj.py`.
- La caméra ne s'allume que pour les exercices qui en ont besoin (Pompes, Autre exercice).

## Exercices
Chaque exercice fixe les capteurs écoutés.

| Exercice | Téléphone | Capteurs |
|---|---|---|
| Autre exercice | posé face à toi, ou porté | tous, le plus régulier l'emporte |
| Pompes | au sol, écran vers le haut, au niveau de la tête | profondeur, visage, image |
| Abdos | à plat contre la poitrine | gyroscope (vitesse de rotation) |
| Squats | poche de pantalon ajustée, ou brassard (avec une barre, les mains sont prises) | accélération verticale, inclinaison |
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
Comme ce geste n'atteint toute son ampleur qu'un instant plus tard, une répétition qui arrive
après une pause attend 0,3 s avant de compter : si le geste continue, bien plus ample, il ne
compte pas.

**Geste appris (abdos)** : l'app apprend en silence la forme de ta répétition, sur les
répétitions comptées en série régulière, et la mémorise d'une séance à l'autre
(`GestureTemplate.swift`) : la forme moyenne sur les 3 axes du gyroscope, son ampleur et sa
durée. Oubli progressif : le poids d'une répétition apprise est divisé par deux tous les 60
jours (12,5 % au bout de 6 mois) ; l'ampleur et la durée sont celles des 100 dernières
répétitions. Dès 10 répétitions apprises, hors série régulière, un geste qui ressemble au gabarit
(cosinus ≥ 0,8, ampleur de 0,5 à 2 fois la tienne, iPhone à plat) compte tout de suite : les
séries irrégulières (pauses variables entre les répétitions) sont comptées, alors que le
compteur, qui attend un rythme régulier, les ratait. Au démarrage d'une série régulière, les
répétitions déjà comptées par le gabarit sont remplacées par le recompte. Séances réelles :
série irrégulière 15/15 (7 sans gabarit), aucune fausse détection en se levant, en marchant,
en posant l'iPhone. Expérience : `Simulation/experiment_template.py`.

Gyroscope (abdos) : chaque répétition fait deux bosses de vitesse, l'aller puis le retour, et
un court repos la sépare de la suivante. La bosse qui suit ce repos ouvre la répétition ; on
compte à la seconde, quand la répétition est finie. Au démarrage du comptage, les répétitions de
la série sont recomptées ainsi. Auparavant, selon la façon dont la série démarrait, on comptait
tantôt à l'aller, tantôt au retour ; à l'aller, la dernière répétition comptait deux fois
(séance réelle du 28/10 : 51 au lieu de 50).

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
les 10, en récupération un bip bref à 15 s, deux bips montants à 30, trois à 45 (la, do#, mi,
espacés de 0,13 s pour se compter à l'oreille) et un accord grave plus long à chaque minute (le
cycle reprend chaque minute), deux notes descendantes en fin de série, un arpège en fin de
séance. Chaque son s'accompagne d'une vibration. Pendant la récupération, une répétition
provisoire isolée (respiration, se replacer) vibre sans sonner : elle ne sonne qu'à partir de la
2e de suite, pour ne pas se mêler aux bips de récupération.

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
- Une répétition compte **à la fin de l'effort**, et le point de départ dépend de l'exercice
  (`Exercise.countsAtFarEnd`) :

  | Exercice | Départ | Compte |
  |---|---|---|
  | Pompes, squats, fentes, dips | en haut | en haut, au retour au départ |
  | Tractions, développé, biceps, rowing | bras tendus | au bout de la traction ou de la poussée, à l'autre extrême |
  | Abdos | allongé | au sommet (gyroscope : début de la redescente) |

  Au démarrage du comptage, la position tenue juste avant la série fixe le départ (sans cela,
  le signe arbitraire de l'ACP pouvait faire compter à mi-chemin) ; on compte au retour à
  cette position, ou à l'extrême opposé. À l'extrême opposé, on compte quand le signal en
  repart (5 % de son ampleur) : au sommet, pas à l'approche. L'accélération verticale compte
  toujours à son creux, qui est le sommet du geste (le ralentissement de la montée), quel que
  soit l'exercice. Tractions rejouées : comptées à 0,25 s du sommet au plus, au lieu de tantôt
  à la montée, tantôt en bas. Pour le gyroscope, le repos est au milieu du signal : le sens
  n'est pas modifié.
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

## Licence
Code sous licence [Apache 2.0](LICENSE). Le nom « Reps » et l'icône de l'app ne sont pas
couverts : voir [NOTICE](NOTICE).
