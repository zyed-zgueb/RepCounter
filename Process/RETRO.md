# Rétrospectives du Builder

Une entrée par fin de cycle ou par défaut trouvé par Vincent : ce qui a échappé, pourquoi, la
pratique qui change. Les plus récentes en haut.

## 01/11 : recette du cycle 2, « tu aurais dû voir l'app plus tôt »

**Ce qui a échappé** : sigles, textes coupés, libellés masqués, incohérences entre écrans, trop
de texte, polices trop petites. Tous visibles d'un coup d'œil sur l'app.

**Pourquoi** : je jugeais l'interface en lisant le code, et je faisais relire le code par un
agent. Ni lui ni moi ne voyions un seul écran. J'ai traité « compile et la logique est juste »
comme « livrable », et j'ai découvert les défauts visibles par Vincent, l'un après l'autre.

**Pratiques qui changent**
1. Aucun écran n'est livré sans que je l'aie vu sur une capture de l'app réelle (iPhone 14,
   clair et sombre), produite par la CI. En place depuis le 01/11.
2. La recette s'écrit à partir des captures, pas de mémoire du code (les « pointillés » du
   journal, invisibles, venaient de là).
3. Ce qui se valide à l'œil, Vincent le valide sur les captures, sans installer.

**Angles morts restants, à fermer avant le cycle 3** (décision du Builder)
- Les captures ne montrent que 3 écrans au repos. Il manque les états qui comptent : jour de
  test, repos conseillé, après le test, pendant la série, la récupération, la fin de séance,
  la page des semaines, le (i). → Le mode capture apprend ces états.
- Pas de capture en grande taille de texte (Dynamic Type) : les débordements ne se voient qu'à
  la taille standard. → Une série de captures en taille d'accessibilité.
- La logique du plan n'est testée qu'en Python, sur un miroir recopié à la main : un écart entre
  le Swift et le Python passerait. → Des tests Swift du plan, lancés par la CI.
- Les relectures par agent partent de mon brief : elles cherchent où je leur dis de chercher.
  → La revue de design se fait sur les captures, avec la grille, sans mon avis préalable.

## 01/11 (soir) : avis de Vincent sur les Nouveautés et la maquette du cycle 3

**Ce qui a échappé** : 7 « À revoir » sur 12 changements, et 2 écrans de maquette sur 3.
- Des puces et des pictogrammes décoratifs (« • intensité », « ! ◆ Série max », « ◆ Lancer le
  test ») : je les prenais pour de la clarté ; ils ajoutent du bruit.
- Des mots vagues (« soutenue », « série max ») qu'un utilisateur ne sait pas relier à son effort.
- Une correction de sigle qui allonge sans rien clarifier (« répétitions par semaine » au lieu de
  « reps », que tout le monde comprend).
- La maquette du cycle 3 a perdu ce que l'app faisait bien (les segments qui s'allument à chaque
  répétition) : je l'ai dessinée de mémoire, sans partir de la capture de l'écran réel.

**Pourquoi** : je jugeais chaque élément seul (« est-ce compréhensible ? ») et pas « est-ce
utile ? ». Et ma grille ne demandait pas ce que l'écran actuel fait de bien, à garder.

**Ce que je change** :
1. Une maquette part toujours de la capture de l'écran réel ; je note d'abord ce qui marche et
   doit rester.
2. Dans la revue de design, pour chaque symbole, puce ou mot : « que perd-on si on l'enlève ? » ;
   si rien, on l'enlève (skill reps-ux § 12, règles ajoutées).
3. Un sigle se remplace par le mot le plus court que tout le monde comprend, pas par une phrase.
