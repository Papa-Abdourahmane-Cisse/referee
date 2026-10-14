# NUM-02 : Parts ou sous-totaux qui ne somment pas au total attendu

**Famille** : NUM (Cohérence numérique)  
**Niveaux de confiance** : certitude  
**Détection** : données, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `sums`

## Ce que la règle détecte

Pour chaque contrôle de `sums`, compare la somme ligne à ligne des colonnes `parts` au total déclaré (colonne `total`) ou à une valeur attendue (`target`), avec une tolérance d'arrondi absolue. Constat de certitude.

## Pourquoi c'est un problème

Des parts qui ne somment pas à 100 % (ou au total déclaré) signalent une catégorie manquante, un doublon ou une erreur de calcul.

## Que faire en cas d'alerte

Vérifier les catégories omises et la tolérance d'arrondi (`tol`) ; corriger la source de l'écart.

## Exemple

```r
rowSums(d[, c('part_a', 'part_b', 'part_c')])
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(sums = list(list(parts = c("a", "b"), target = 100))))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

