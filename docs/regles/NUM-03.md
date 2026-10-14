# NUM-03 : Ordre des indices FGT violé (FGT2 <= FGT1 <= FGT0)

**Famille** : NUM (Cohérence numérique)  
**Niveaux de confiance** : certitude  
**Détection** : données, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `fgt_cols`

## Ce que la règle détecte

Pour tout seuil et tout agrégat, FGT2 <= FGT1 <= FGT0 (l'écart relatif normalisé est compris entre 0 et 1, donc son carré est inférieur à l'écart, lui-même inférieur à l'indicatrice de pauvreté). Une violation est un constat de certitude.

## Pourquoi c'est un problème

Pour tout seuil, FGT2 ≤ FGT1 ≤ FGT0 : le carré de l'écart relatif normalisé est inférieur à l'écart, lui-même inférieur à l'indicatrice de pauvreté. Une violation est une erreur de calcul.

## Que faire en cas d'alerte

Contrôler la formule des indices (valeur de α, traitement des non-pauvres, normalisation par la ligne de pauvreté) et l'ordre des colonnes déclarées.

## Exemple

```r
all(d$fgt2 <= d$fgt1 & d$fgt1 <= d$fgt0)
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(fgt_cols = c("fgt0", "fgt1", "fgt2")))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

