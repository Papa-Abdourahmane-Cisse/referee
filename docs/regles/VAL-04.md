# VAL-04 : Jeu de test utilisé pour choisir les hyperparamètres ou le modèle

**Famille** : VAL (Validation en apprentissage automatique)  
**Niveaux de confiance** : risque probable  
**Détection** : statique, métadonnées  
**Entrées requises** : un script R ; métadonnées : `test_objects`

## Ce que la règle détecte

Signale les fonctions de réglage (`tune_grid()`, `train()`, `cv.glmnet()`, etc.) ou de rééchantillonnage (`vfold_cv()`, `bootstraps()`, etc.) dont les arguments citent un objet de test déclaré. Le test doit rester intact jusqu'à l'évaluation finale. Les boucles de réglage écrites à la main ne sont pas détectées.

## Pourquoi c'est un problème

Choisir hyperparamètres ou modèle d'après le test rend la performance finale optimiste : le test a participé à la sélection.

## Que faire en cas d'alerte

Réserver le test à l'évaluation finale ; régler par validation croisée dans l'apprentissage.

## Exemple

```r
tune_grid(wf, resamples = vfold_cv(test))   # alerte
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R",
                  meta = referee_meta(test_objects = "test"))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

