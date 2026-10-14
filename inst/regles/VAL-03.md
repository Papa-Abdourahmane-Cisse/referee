# VAL-03 : Performance calculée sur les données d'apprentissage

**Famille** : VAL (Validation en apprentissage automatique)  
**Niveaux de confiance** : risque probable  
**Détection** : statique, métadonnées  
**Entrées requises** : un script R ; métadonnées : `train_objects`

## Ce que la règle détecte

Signale les prédictions (`predict()`, `augment()`) et les métriques (`rmse()`, `RMSE()`, `cor()`, etc.) qui citent un objet d'apprentissage déclaré, lorsqu'aucun appel d'évaluation ne cite un jeu de test déclaré. Rapporter une performance d'apprentissage à côté d'une performance de test est légitime : si `test_objects` est fourni et qu'une évaluation sur le test existe, la règle ne signale rien. Elle ne peut pas savoir comment le résultat est présenté dans le rapport.

## Pourquoi c'est un problème

La performance sur les données qui ont servi à ajuster le modèle mesure la capacité d'ajustement, pas de prédiction.

## Que faire en cas d'alerte

Rapporter la performance de validation croisée ou sur un test indépendant ; si la performance d'apprentissage est donnée, la présenter comme telle, à côté de la précédente.

## Exemple

```r
rmse(train$y, predict(m, train))   # alerte (si rien sur le test)
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R",
                  meta = referee_meta(train_objects = "train"))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

