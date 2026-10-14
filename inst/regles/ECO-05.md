# ECO-05 : Discontinuité de régression : accumulation au seuil ou absence de test de manipulation

**Famille** : ECO (Économétrie et identification)  
**Niveaux de confiance** : risque probable, à justifier  
**Détection** : données, statique, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `score`, `cutoff`

## Ce que la règle détecte

Deux contrôles. (1) À partir des données : test binomial bilatéral de l'égalité des effectifs dans deux fenêtres de même largeur de part et d'autre du seuil (sous continuité de la densité, ils sont voisins). Un rejet au niveau `alpha` signale une accumulation d'un côté du seuil. C'est un criblage grossier, pas un test de manipulation : une densité de pente marquée au seuil, ou des scores arrondis qui s'accumulent sur le seuil lui-même, peuvent le déclencher sans manipulation. Le test de densité dédié (`rddensity`) fait référence. (2) Si un script est fourni, signale l'absence de tout appel à un test de densité (`rddensity()`, `DCdensity()`).

## Pourquoi c'est un problème

Si des unités peuvent manipuler leur score autour du seuil, l'hypothèse d'assignation quasi aléatoire de la discontinuité tombe.

## Que faire en cas d'alerte

Réaliser le test de densité dédié (`rddensity::rddensity()`), examiner l'histogramme du score et justifier l'absence de manipulation par les institutions.

## Exemple

```r
rddensity::rddensity(X = d$score, c = seuil)
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(score = "score", cutoff = 50))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

