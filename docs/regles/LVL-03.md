# LVL-03 : Clé censée être unique présente en double

**Famille** : LVL (Niveaux d'analyse)  
**Niveaux de confiance** : certitude  
**Détection** : données  
**Entrées requises** : des données (data frame) ; métadonnées : `key`

## Ce que la règle détecte

Une clé censée identifier une unité de manière unique apparaît plusieurs fois. Seul le constat sur les données est couvert ici : l'augmentation du nombre de lignes après une jointure suppose de comparer deux états de la base, ce que la règle ne fait pas.

## Pourquoi c'est un problème

Une clé en double dans une base censée avoir une ligne par unité fausse les effectifs, les moyennes et les jointures.

## Que faire en cas d'alerte

Identifier les doublons (`duplicated()`), déterminer s'il s'agit d'une saisie répétée ou d'une clé mal définie, et corriger avant toute estimation.

## Exemple

```r
d[duplicated(d$id) | duplicated(d$id, fromLast = TRUE), ]
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(key = "id"))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

