# Reps : règles de travail des agents

Ce fichier est chargé par chaque session Claude ouverte sur ce dépôt. Il prime sur toute
organisation plus ancienne décrite ailleurs (messages, branches, anciennes sessions).

## L'équipe
- **Vincent** fixe l'objectif du cycle, tranche les questions de produit, fait la recette sur
  l'iPhone. Il ne relaie pas de messages entre agents.
- **Builder** (une seule session à la fois) : produit, science du sport et code, dans un même
  contexte. Il conçoit, source, code, fait compiler, teste, livre.
- **Reviewer** (ponctuel) : une relecture par lot, avec `Process/RELECTURE.md`. Lancé par le
  Builder (sous-agent) ou par Vincent ; il ne conçoit pas, il rend un seul rapport au Builder.

Pas d'autre session permanente. Pas de messages entre sessions : ce qui doit durer est écrit
dans le dépôt.

## Le cycle
1. **Cadrage** : `Process/CYCLE.md` porte l'objectif du cycle en une phrase vérifiable, ce qui
   est dedans, ce qui est dehors, et 3 questions à Vincent au plus, chacune avec des options et
   une recommandation. Rien ne se code avant que Vincent ait validé le cadrage.
2. **Construction** : le Builder décide seul de tout ce qui n'est pas une question de produit, et
   note chaque décision qui compte dans `DECISIONS.md`.
3. **Relecture** : une seule, en fin de lot. Le Builder corrige, sans seconde relecture sauf
   défaut bloquant.
4. **Livraison** : CI verte, puis une seule réponse à Vincent avec la recette (`Process/RECETTE.md`
   remplie : 5 à 10 vérifications sur l'iPhone).
5. **Recette** : Vincent coche ; ses retours ouvrent le cycle suivant (ou un correctif dans le
   même cycle s'il s'agit d'un défaut).

## Les règles
- **Rien n'est livré sans compiler.** La CI (`.github/workflows/build.yml`) compile l'app et
  rejoue la simulation du compteur. Un lot rouge n'est pas proposé à Vincent.
- **Hors cycle = backlog.** Une idée qui sort de l'objectif va dans la section « Backlog » de
  `Process/CYCLE.md`, sans être faite.
- **Une décision prise ne se rediscute pas sans fait nouveau.** Avant de proposer, lire
  `DECISIONS.md`. Pour revenir sur une décision, citer le fait nouveau.
- **Questions à Vincent** : seulement au cadrage ou sur un blocage réel ; jamais plus de 3 à la
  fois ; toujours avec options et recommandation. Le reste, l'agent le décide et le note.
- **Budget** : si un même point revient une 3ᵉ fois (correction de correction), on s'arrête et
  on pose la question à Vincent au lieu de reboucler.
- **Une seule source de vérité, sur `main`** : écrans et textes dans le skill reps-ux, méthodes
  d'entraînement dans `Science/`, décisions dans `DECISIONS.md`. Aucun document de référence ne
  reste sur une branche annexe.
- **Sources scientifiques** : toute règle d'entraînement cite sa source et dit si elle a été lue
  en texte intégral, en résumé, ou si c'est un choix de l'app (voir `Science/`).
- **Le cœur d'abord** : compter juste passe avant l'habillage. Toute modification de
  `AutoCounter.swift` se reporte dans `Simulation/simulate_counter.py`, et la simulation doit
  rester exacte.

## Repères
- `README.md` : ce que fait l'app et comment.
- `.claude/skills/reps-ux/SKILL.md` : où va chaque donnée, à charger avant de toucher un écran.
- `Science/` : méthodes d'entraînement et leurs sources.
- `DECISIONS.md` : journal des décisions.
- `Process/` : cycle en cours, modèle de recette, grille de relecture.
