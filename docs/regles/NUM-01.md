# NUM-01 : Proportion ou taux hors bornes, échelles mélangées

**Famille** : NUM (Cohérence numérique)  
**Niveaux de confiance** : certitude, risque probable  
**Détection** : données, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `scales`

## Ce que la règle détecte

Pour chaque colonne de `scales`, signale les valeurs hors de [0 ; 1] (`"proportion"`) ou de [0 ; 100] (`"percent"` et `"auto"`). Constat de certitude.
Pour une colonne déclarée `"auto"`, signale aussi un mélange probable de proportions et de pourcentages : des valeurs inférieures ou égales à 1 et des valeurs supérieures à 1 présentes en nombre et en part notables. Ce second constat n'est qu'un risque probable : un pourcentage faible et un pourcentage élevé peuvent coexister légitimement. Les seuils `mixed_min_n` et `mixed_min_share` sont des conventions de pratique à calibrer.

## Pourquoi c'est un problème

Une proportion hors de [0 ; 1] ou un pourcentage hors de [0 ; 100] est impossible ; des échelles mélangées dans une même colonne rendent toute moyenne ininterprétable.

## Que faire en cas d'alerte

Retrouver l'origine des valeurs (saisie, conversion) et homogénéiser l'échelle. Pour le mélange probable (`auto`), vérifier dans la documentation si la colonne est en pourcentage ou en proportion.

## Exemple

```r
range(d$taux, na.rm = TRUE)
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(scales = c(taux = "proportion")))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

