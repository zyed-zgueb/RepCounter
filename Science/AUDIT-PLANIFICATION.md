# Audit des règles de planification — version provisoire

Session « Science du sport », 30 octobre 2026. Pour Vincent : à valider avant tout envoi au dev.

## À lire d'abord : ce que j'ai pu lire

Le réseau de la session bloque les textes intégraux : PubMed Central, Europe PMC, MDPI, PeerJ,
Springer, LWW. Seule la recherche web passe. Elle ne donne que des **résumés** (abstracts,
notices, articles de blog).

Conséquences :
- **Aucune source de ce document n'a été lue en texte intégral par moi.** Pas de citation exacte
  avec page ici : je ne peux pas les vérifier.
- Colonne « Lu » : **R** = résumé ou notice seulement ; **S** = source secondaire (blog, article qui
  la cite) ; **C** = lu en texte intégral par la session Produit, non revérifié par moi.
- ACSM 2026 : référence **confirmée** par la session Produit, sur le PDF fourni par Vincent.
  *Med Sci Sports Exerc* 58(4):851–872, DOI 10.1249/MSS.0000000000003897, CC BY-NC-ND 4.0. Une
  source secondaire donnait 58(3):512–545 : c'est une erreur. Citations exactes du PDF, pages de
  la revue :
  - p. 859 : « There were insufficient data to determine if muscular endurance was affected by
    load (82), unstable surfaces (70), power training (82), volume (82), or set structure
    (107,108). »
  - p. 863 : « at least twice weekly » ; « the same relative load can also be sustained when
    regular strength testing is performed or perceived exertion scales are used to increase
    absolute load commensurate with strength gains » ; « With appropriate progressive overload,
    periodization is not significantly superior to nonperiodized programs ».
  - p. 864 : « at least two sets per exercise » ; « completion of “near-failure” or a target of
    2–3 repetitions in reserve (RIR) » ; « there is insufficient evidence to quantify exact RIR
    and perceived exertion targets » ; « Methods to quantify load based on proximity to muscular
    failure (e.g., RIR, perceived exertion) are appealing because they could translate to various
    RT forms (e.g., elastic band or body weight RT). »
  - p. 856 : la force n'est pas affectée par un repos court (< 1 min) ou long (> 1 min) entre les
    séries.
  Je n'ai pas lu ce PDF moi-même ; ces citations viennent de la session Produit.
- Pour finir le travail, il faut ouvrir ces domaines dans les réglages réseau de l'environnement
  (Edit › Network access › Allowed domains) : `www.ebi.ac.uk`, `pmc.ncbi.nlm.nih.gov`,
  `www.ncbi.nlm.nih.gov`, `eutils.ncbi.nlm.nih.gov`, `pubmed.ncbi.nlm.nih.gov`, `peerj.com`,
  `www.mdpi.com`, `jssm.org`, `sportrxiv.org`.
  Aide : https://code.claude.com/docs/en/cloud-environments#network-access
  Autre solution : déposer les PDF dans la session.

Les décisions ci-dessous sont donc des **propositions à confirmer** sur texte intégral. Aucune
ne doit partir au dev avant.

## 1. Le point faible : progresser en endurance au poids du corps

**Ce que dit la littérature (résumés seulement)**
- Pour améliorer un max de répétitions, des séries **longues** (≥ 15 répétitions) font mieux que
  des séries lourdes et courtes. Source : Hackett et al., méta-analyse (14 études), *Science &
  Sports* 37:405–420 (2022 ; l'année reste à vérifier). R. Limite : les tests y portent sur une
  charge externe, pas sur le poids du corps.
- **Plusieurs séries** valent mieux qu'une. Source : Radaelli et al. 2015, *J Strength Cond Res*
  (essai contrôlé, 48 hommes non entraînés, 6 mois). R.
- **Aller à l'échec n'apporte pas plus** et fatigue davantage. Sources : Grgic et al. 2022,
  méta-analyse (15 études, sans mesure d'endurance) ; Vieira et al. 2021. R.
- Charge légère : environ **+17 % d'endurance en 8 semaines**. Source : Schoenfeld et al. 2015,
  *J Strength Cond Res* 29:2954 (18 hommes entraînés, développé couché à 50 % du max). R.
- Pompes à l'échec 2 fois par semaine pendant 8 semaines : **endurance inchangée**. Source :
  Kikuchi & Nakazato 2017, *J Exerc Sci Fit* (PMC5812864, 18 hommes). R. Le progrès n'est donc
  pas garanti.
- Tractions : dans deux essais de 2025 (tirage vertical, 8 semaines), le nombre de tractions
  augmente dans tous les groupes (PMC11766678, PMC11667758). R.
- **Séries réparties dans la journée** (« exercise snacks ») : un seul résumé de congrès sur un
  petit groupe (Int J Exerc Sci). Les pompes progressent autant qu'avec des séries max. R.
  Preuve très faible.
- **Aucune donnée trouvée** sur :
  - la fréquence optimale pour l'endurance ;
  - le repos ou la densité ;
  - une prescription en % du max de répétitions ;
  - la vitesse de progression typique d'un max de pompes ou de tractions.
- L'ACSM 2026 le dit aussi : données insuffisantes sur le dosage (C).

**Lecture pour Reps**
- La méthode actuelle va dans le sens des résumés : plusieurs séries, près de l'échec sans y
  aller, avec la progression vérifiée par les tests.
- Avec un max de 30 pompes, les séries font déjà ≥ 15 répétitions : cohérent avec Hackett.
- Le vrai trou : **les exercices à petit max** (tractions à 5, dips à 6). Les séries y sont
  courtes, loin de la zone « endurance ». La littérature ne dit pas comment faire.
  Les options sont des choix de l'app :
  - plus de séries ;
  - une variante plus facile (traction assistée, pompe inclinée) ;
  - des séries réparties.
  Je ne propose pas de règle avant d'avoir lu les textes.

## 2. Tableau des règles

Niveau de preuve : **fort** (méta-analyses concordantes), **moyen** (une méta-analyse, ou des
essais transposés), **faible** (avis d'experts, enquêtes, petites études), **aucun**.

| # | Règle actuelle | Meilleure référence trouvée | Lu | Preuve | Décision proposée |
|---|---|---|---|---|---|
| 1 | ≥ 2 séances/sem. | ACSM 2026 (Currier et al.) ; Grgic 2018 (méta-analyse : à volume égal, la fréquence change peu) | C, S | Fort (force) ; aucun propre à l'endurance | **Garder.** |
| 2 | 3 séries | ACSM 2026 (2–3 séries) ; Radaelli 2015 (plusieurs séries > une) | C, R | Moyen | **Garder.** |
| 3 | Série 1 = max − 3 | ACSM 2026 (2–3 en réserve, cible exacte non établie) ; Halperin 2022, méta-analyse : on se trompe d'environ 1 répétition sur ce qu'il reste, davantage sur les séries longues | C, R | Faible pour le chiffre | **Garder, choix de l'app.** Atout : la cible vient d'un max compté, pas d'une estimation de la personne. **Ajout proposé (choix de l'app)** : une série faite ≥ 3 au-dessus de sa cible relève le max. Sinon, le max reste figé 4 semaines alors que la personne progresse. |
| 4 | Séries suivantes : baisse habituelle, sinon 80 % | Revues sur le repos (de Salles 2009 ; Grgic 2018) : la baisse est plus forte avec un repos court. Aucun chiffre par série trouvé, rien sur pompes ou tractions | R, S | Aucun pour 80 % | **Garder la baisse personnelle** (mesurée, donc la meilleure base). **80 % reste un choix de l'app, non sourcé.** Le caler sur de vraies séances (Recordings). |
| 5 | Repos habituel | ACSM 2026 : pas d'effet sur la force ; de Salles 2009 : 3–5 min permettent plus de répétitions | C, R | Moyen | **Garder.** |
| 6 | Bloc 3 + 1 + test | Bell 2023 (Delphi : définit la décharge, sans fréquence) ; Rogerson 2024 (enquête, 246 athlètes : décharge toutes les 5,6 ± 2,3 semaines) ; Coleman 2024 (essai : une semaine sans entraînement ne nuit pas à l'endurance) | R | Faible | **Reste un choix de l'app.** 4 semaines entre dans la pratique courante. Rien ne prouve qu'un autre rythme fasse mieux. |
| 7 | Semaine allégée = moitié des séries | Bosquet 2007, méta-analyse sur l'affûtage : volume −41 à −60 %, intensité et fréquence gardées. Travis 2020, revue (force), dans le même sens | R, S | Moyen par analogie (affûtage, sportifs d'endurance) | **Garder.** Citer Bosquet 2007 et garder le même nombre de séances. Ce n'est plus un pur choix de l'app, mais une transposition. |
| 8 | Progression par le test, sans hausse hebdomadaire | ACSM 2026 : tests réguliers, aucun rythme chiffré | C | Aucun pour un rythme | **Garder**, avec l'ajout du point 3. |
| 9 | Test = 1re série de la 1re séance après la date | Fiabilité du test de pompes : écart de 10 à 20 % d'un test à l'autre chez des débutants, effet d'apprentissage (études de fiabilité sur jeunes ou petits groupes) | R | Faible à moyen | **À revoir.** La relecture signale qu'une série isolée ou une séance de reprise devient le test. Proposition : le test est une **série max déclarée** (jour de test affiché), pas n'importe quelle série. Un écart de test sous ~10 % se lit comme du bruit. |
| 10 | Semaine 1 de calibrage (bloc 1) | Mêmes études : familiarisation recommandée, au moins 2 essais | R | Faible à moyen | **Meilleure base** : le premier test sert de familiarisation. Un 2e test dans la semaine, et on garde le meilleur des deux. Règle à confirmer sur texte intégral. Absente du code actuel. |
| 11 | Semaine de reprise après > 7 j | Bosquet 2013, méta-analyse sur l'arrêt de l'entraînement (103 études) : l'endurance (force sous-maximale) baisse le plus ; la perte croît avec la durée de l'arrêt | R | Moyen pour la perte ; aucun pour l'effet d'une semaine de reprise | **Seuil > 7 j : choix de l'app.** **Remplacé** par les seuils validés par Vincent (609d333) : plus de 7 j → semaine de reprise ; plus de 28 j → nouveau bloc 1 avec calibrage. Voir METHODE-TEST.md. La relecture signale que le plan disparaît après 28 j. Prévoir une semaine allégée puis un test. |
| 12 | Objectif proposé = niveau + 20 % | Aucune base pour 20 %. McEwan 2016, méta-analyse : se fixer un but augmente l'activité. Seul ordre de grandeur trouvé : ~+17 % en 8 semaines (Schoenfeld 2015, charge externe) | R | Aucun pour 20 % | **Reste un choix de l'app**, présenté comme point de départ modifiable. C'est déjà le cas. |
| 13 | Semaine refaite (séances manquées, ou Forme basse × 2) | Saw 2016, revue : le ressenti suit la charge ; Meeusen 2013 : aucun marqueur seul ne suffit | R | Aucun pour la règle | **Reste un choix de l'app**, prudent. Garder : la Forme basse se juge par rapport à la référence de la personne, sur 2 mesures. |
| 14 | Jours : lun-jeu, lun-mer-ven | Aucune | — | Aucun | **Reste un choix de l'app.** |
| 15 | Seuil de 4 séances par jour | Aucune ; un seul résumé de congrès sur les séries réparties | R | Aucun | **Reste un choix de l'app.** Absent du code actuel. |

## 3. Méthode proposée (provisoire)

1. **Structure inchangée** : ≥ 2 séances par semaine, 3 séries près de l'échec (max − 3), repos
   habituel. Puis 3 semaines, une semaine allégée (moitié des séries) et un test.
2. **Le max suit la personne entre deux tests** : une série ≥ 3 au-dessus de sa cible relève le
   max. Choix de l'app.
3. **Tests plus fiables** :
   - le test est une série max déclarée ;
   - au bloc 1, deux tests et on garde le meilleur ;
   - un écart sous ~10 % ne se lit pas comme un progrès.
4. **Reprise** : après une pause, repartir du dernier test, faire une semaine allégée, puis un
   test.
5. **Exercices à petit max** (tractions, dips) : question ouverte, à traiter après lecture des
   textes. Pistes à évaluer : variante plus facile, séries réparties.
6. Tout le reste est inchangé, et ses mentions « choix de l'app » sont confirmées.

## 4. Ce qui reste à faire

- Lire en texte intégral, une fois le réseau ouvert :
  - Hackett 2022 ; Schoenfeld 2015 et 2021 ; Kikuchi 2017 ;
  - Bosquet 2007 et 2013 ; Rogerson 2024 ; Coleman 2024 ;
  - Halperin 2022 ; Saw 2016 ; Meeusen 2013 ;
  - les études de fiabilité des tests de pompes et de tractions ;
  - l'ACSM 2026 (le PDF existe : à me transmettre).
  
  Ajouter ensuite les citations exactes avec page.
- Chiffrer la baisse réelle d'une série à l'autre sur les séances enregistrées. Recordings/ n'en
  contient pas encore assez.
