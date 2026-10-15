# SER-01 : Test de racine unitaire appliqué aux résidus d'une régression de niveaux (valeurs critiques inadaptées)

**Famille** : SER (Séries temporelles)  
**Niveaux de confiance** : risque probable  
**Détection** : statique  
**Entrées requises** : un script R

## Ce que la règle détecte

Signale un test de racine unitaire ou de stationnarité (`adf.test()`, `ur.df()`, `pp.test()`, `kpss.test()`, etc.) appliqué aux résidus d'une régression `lm()` entre séries, ce que fait le test de cointégration d'Engle-Granger en deux étapes. Des résidus estimés ne suivent pas la distribution du test appliqué à une série observée : les valeurs critiques usuelles ne conviennent pas, il faut celles d'Engle-Granger (MacKinnon) ou un test conçu pour les résidus de cointégration (`po.test()`, `ca.po()`). Le script est lu dans l'ordre : l'objet testé est reconnu s'il provient de `reg$residuals`, `residuals(reg)`, `resid(reg)` ou d'une variable affectée ainsi, et si `reg` est un `lm()` dont la formule comporte au moins un régresseur autre qu'une tendance. La règle est rapportée « non évaluée » si le script ne contient aucun test de racine unitaire reconnu.

## Pourquoi c'est un problème

Le test de cointégration d'Engle-Granger applique un test de racine unitaire aux résidus d'une régression de niveaux. Ces résidus sont estimés : leur distribution sous l'hypothèse nulle diffère de celle d'une série observée, et les valeurs critiques usuelles du test de Dickey-Fuller ne conviennent pas. Les p-values affichées ne sont alors pas interprétables comme un test de cointégration.

## Que faire en cas d'alerte

Comparer la statistique aux valeurs critiques d'Engle-Granger (MacKinnon), ou utiliser un test conçu pour ce cas (`tseries::po.test()`, `urca::ca.po()`), ou la procédure de Johansen. Vérifier d'abord que les deux séries sont intégrées du même ordre (tests sur les niveaux et sur les différences) et justifier la spécification déterministe. Si la régression n'a pas pour objet la cointégration, écarter le constat.

## Exemple

```r
reg <- lm(x ~ y)
adf.test(residuals(reg))   # alerte
tseries::po.test(cbind(x, y))
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R")
rapport
```

## Limites connues

Limites connues : la règle lit la syntaxe, pas l'intention. Une régression de niveaux dont les résidus sont testés pour une autre raison que la cointégration est signalée à tort (constat « risque probable », à écarter après lecture) ; les valeurs critiques corrigées appliquées à la main ne sont pas reconnues ; les modèles autres que `lm()` (`dynlm()`, `plm()`) et les résidus obtenus par `do.call()` ou une fonction personnalisée échappent à la règle. Elle ne vérifie ni l'ordre d'intégration des séries ni le choix des retards.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

