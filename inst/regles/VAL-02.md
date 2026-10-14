# VAL-02 : Transformation apprise sur l'ensemble des données avant la séparation

**Famille** : VAL (Validation en apprentissage automatique)  
**Niveaux de confiance** : risque probable  
**Détection** : statique  
**Entrées requises** : un script R

## Ce que la règle détecte

Signale une transformation dont les paramètres sont estimés sur les données (`scale()`, `prcomp()`, `preProcess()`, imputation par `mice()`, etc.) lorsqu'elle apparaît dans une instruction de premier niveau antérieure au premier découpage des données. L'ordre est établi par le script ; l'effet sur la performance reste à mesurer, d'où un risque probable.

## Pourquoi c'est un problème

Une transformation dont les paramètres sont appris (moyenne et écart-type d'une standardisation, ACP, imputation) avant le découpage transmet de l'information du jeu de test au jeu d'apprentissage (fuite d'information).

## Que faire en cas d'alerte

Apprendre la transformation sur l'apprentissage seulement, à l'intérieur de chaque pli de validation (`recipes`, `caret::preProcess` dans `train`, pipeline `sklearn`).

## Exemple

```r
d$x <- scale(d$x); initial_split(d)   # alerte
initial_split(d); recipe(...) %>% step_normalize(x)
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R")
rapport
```

## Limites connues

Limites connues : seules les instructions de premier niveau sont comparées (deux appels dans une même instruction ne sont pas ordonnés) ; les définitions de fonctions sont ignorées ; la sélection de variables n'est pas détectée. Sans aucun découpage reconnu dans le script, la règle est non évaluée.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

