# LVL-02 : Moyenne simple d'unités agrégées

**Famille** : LVL (Niveaux d'analyse)  
**Niveaux de confiance** : risque probable  
**Détection** : statique, métadonnées  
**Entrées requises** : un script R ; métadonnées : `aggregated_vars`

## Ce que la règle détecte

Signale `mean()` appelée sur une variable déclarée comme agrégée (un taux communal, par exemple). Si le résultat est présenté comme valeur d'un niveau supérieur, il faut pondérer par la population de chaque unité.

## Pourquoi c'est un problème

La moyenne simple de taux communaux n'est pas le taux du niveau supérieur : elle donne le même poids à une commune de 500 et à une commune de 500 000 habitants.

## Que faire en cas d'alerte

Pondérer par la population de chaque commune, ou recalculer le taux à partir des effectifs agrégés (numérateurs et dénominateurs).

## Exemple

```r
mean(communes$taux)   # alerte
weighted.mean(communes$taux, communes$pop)
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R",
                  meta = referee_meta(aggregated_vars = "taux_commune"))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

