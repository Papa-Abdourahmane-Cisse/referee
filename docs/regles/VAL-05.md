# VAL-05 : Prédicteur quasi déterministe de la cible

**Famille** : VAL (Validation en apprentissage automatique)  
**Niveaux de confiance** : risque probable  
**Détection** : données, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `target`

## Ce que la règle détecte

Signale les variables numériques dont la corrélation avec la cible, en valeur absolue (maximum de la corrélation de Pearson et de celle de Spearman, sur les paires complètes), atteint le seuil. Une telle variable est souvent dérivée de la cible ou issue de la même source (fuite d'information). Une variable légitime très prédictive peut aussi dépasser le seuil : la règle demande une justification, pas une suppression. Seuil indicatif, à calibrer.

## Pourquoi c'est un problème

Une variable presque parfaitement corrélée à la cible est souvent dérivée de la cible ou issue de la même source : elle ne sera pas disponible au moment de la prédiction.

## Que faire en cas d'alerte

Déterminer l'origine de la variable ; l'exclure si elle contient l'information de la cible, la conserver et le justifier si elle est une cause légitime très prédictive.

## Exemple

```r
cor(d$x, d$y)   # |r| proche de 1 : examiner
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(target = "y"))
rapport
```

## Limites connues

Limites connues : les prédicteurs non numériques et les relations non monotones ne sont pas examinés.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

