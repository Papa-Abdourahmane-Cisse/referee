# REP-02 : Procédure stochastique sans graine aléatoire

**Famille** : REP (Reproductibilité)  
**Niveaux de confiance** : certitude, risque probable  
**Détection** : statique  
**Entrées requises** : un script R

## Ce que la règle détecte

Signale, pour chaque fonction stochastique reconnue (`sample()`, `rnorm()`, `ranger()`, `vfold_cv()`, `kmeans()`, etc.), les appels de premier niveau qui ne sont précédés d'aucun `set.seed()` (ni `with_seed()`) dans le script, et qui ne reçoivent pas d'argument `seed`. Sans graine, deux exécutions donnent des résultats différents : constat de certitude. Si le script appelle `source()`, la graine peut être fixée ailleurs : le constat devient un risque probable.

## Pourquoi c'est un problème

Sans graine, un échantillonnage, un découpage ou un modèle aléatoire donne des résultats différents à chaque exécution : les chiffres du rapport ne sont pas reproductibles.

## Que faire en cas d'alerte

Appeler `set.seed()` en début de script (et par flux pour un calcul parallèle) et noter la graine dans le rapport.

## Exemple

```r
set.seed(2024)
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R")
rapport
```

## Limites connues

Limites connues : les appels situés dans des définitions de fonctions sont ignorés ; une graine unique en début de script ne garantit pas la reproductibilité d'un calcul parallèle, dont les flux aléatoires se règlent séparément ; la liste des fonctions n'est pas exhaustive.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

