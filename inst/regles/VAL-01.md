# VAL-01 : Validation croisée aléatoire alors que les observations sont groupées

**Famille** : VAL (Validation en apprentissage automatique)  
**Niveaux de confiance** : risque probable  
**Détection** : statique, métadonnées  
**Entrées requises** : un script R ; métadonnées : `group`

## Ce que la règle détecte

Quand une variable de groupe est déclarée (région, grappe, commune), signale les découpages aléatoires (`vfold_cv()`, `initial_split()`, `createFolds()`, `trainControl(method = "cv")`, etc.) en l'absence de tout découpage groupé ou spatial dans le script. Avec des observations corrélées au sein d'un groupe, un découpage aléatoire place des observations d'un même groupe dans l'apprentissage et dans le test : la performance estimée risque d'être optimiste. L'ampleur de l'écart dépend des données et ne peut être établie que par comparaison avec une validation groupée.

## Pourquoi c'est un problème

Quand des observations d'un même groupe (région, grappe) sont corrélées, un découpage aléatoire place des voisines dans l'apprentissage et le test : la performance mesurée est optimiste pour la prédiction de nouveaux groupes.

## Que faire en cas d'alerte

Utiliser un découpage groupé (`group_vfold_cv()`, `spatial_block_cv()`) si le modèle doit prédire pour des groupes non vus, et comparer avec le découpage aléatoire pour mesurer l'écart.

## Exemple

```r
vfold_cv(d, v = 5)   # alerte
group_vfold_cv(d, group = region, v = 5)
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R",
                  meta = referee_meta(group = "region"))
rapport
```

## Limites connues

Limite connue : un seul découpage groupé n'importe où dans le script suffit à faire taire la règle, même s'il ne concerne pas le modèle principal.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

