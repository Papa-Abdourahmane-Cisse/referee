# VAL-06 : Validation aléatoire sur des données ordonnées dans le temps

**Famille** : VAL (Validation en apprentissage automatique)  
**Niveaux de confiance** : risque probable  
**Détection** : statique, métadonnées  
**Entrées requises** : un script R ; métadonnées : `time`

## Ce que la règle détecte

Quand une variable temporelle est déclarée, signale les découpages aléatoires en l'absence de tout découpage temporel (`rolling_origin()`, `initial_time_split()`, `createTimeSlices()`, `tsCV()`, etc.) dans le script. Un découpage aléatoire utilise des observations futures pour prédire des observations passées.

## Pourquoi c'est un problème

Un découpage aléatoire d'une série temporelle utilise le futur pour prédire le passé : la performance est optimiste pour une prévision réelle.

## Que faire en cas d'alerte

Utiliser un découpage temporel (`rolling_origin()`, `initial_time_split()`, `createTimeSlices()`).

## Exemple

```r
initial_split(d)   # alerte
initial_time_split(d)
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R",
                  meta = referee_meta(time = "annee"))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

