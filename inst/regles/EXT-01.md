# EXT-01 : Écart non expliqué avec une valeur de référence déclarée

**Famille** : EXT (Cohérence externe)  
**Niveaux de confiance** : à justifier  
**Détection** : données, métadonnées  
**Entrées requises** : des métadonnées seules ; métadonnées : `references`

## Ce que la règle détecte

Pour chaque référence déclarée (valeur officielle ou publiée), compare l'estimation du travail à cette valeur. L'estimation est soit fournie (`estimate`), soit calculée comme la moyenne d'une variable (`var`), pondérée si une variable de poids est déclarée, simple sinon (le message le précise). Un écart supérieur à la tolérance est un constat à justifier : le rapport liste les causes à examiner. La règle ne dit pas laquelle des deux valeurs est la bonne.
Si l'estimation, multipliée ou divisée par 100, se rapproche de la référence, le message signale un possible écart d'échelle (proportion et pourcentage). La moyenne d'une variable 0/1 est une proportion d'unités (ménages ou individus selon les lignes) : c'est à l'utilisateur de vérifier que l'unité d'analyse est celle de la référence.

## Pourquoi c'est un problème

Un écart avec une valeur officielle publiée peut venir d'une différence de définition, de période, de population, de seuil, de pondération ou de méthode ; il peut aussi venir d'une erreur. La statistique officielle n'est pas automatiquement la bonne.

## Que faire en cas d'alerte

Passer en revue les causes listées par le rapport, en commençant par l'échelle (proportion ou pourcentage) et la pondération, puis documenter l'écart résiduel.

## Exemple

```r
referee_meta(weights = 'poids', references = list(list(name = 'taux emploi', reference = 0.42, tol = 0.02, var = 'emploi')))
```

## Utilisation

```r
library(referee)
rapport <- audit(meta = referee_meta(references = list(list(name = "taux", reference = 0.42, tol = 0.02, var = "emploi"))))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

