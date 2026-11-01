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
