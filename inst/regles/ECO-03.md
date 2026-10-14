# ECO-03 : Double différence sans examen des tendances pré-traitement

**Famille** : ECO (Économétrie et identification)  
**Niveaux de confiance** : à justifier  
**Détection** : statique, métadonnées  
**Entrées requises** : un script R ; métadonnées : `treat`

## Ce que la règle détecte

Signale une régression qui cite la variable de traitement déclarée lorsque le script ne contient aucune trace d'examen des tendances pré-traitement : étude d'événement (`i(..., ref = )`, `sunab()`, `att_gt()`), retards et avances (`lead`), `HonestDiD`, etc. Des tendances parallèles ne se prouvent pas ; leur examen reste attendu. La règle exige une justification.

## Pourquoi c'est un problème

L'hypothèse de tendances parallèles ne se prouve pas, mais son examen sur les périodes pré-traitement est la pratique attendue.

## Que faire en cas d'alerte

Présenter une étude d'événement avec leads et lags (`i(temps_relatif, traite, ref = -1)`), et envisager une analyse de sensibilité (`HonestDiD`).

## Exemple

```r
feols(y ~ i(t_rel, traite, ref = -1) | unite + annee, data = d)
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R",
                  meta = referee_meta(treat = "traite"))
rapport
```

## Limites connues

Limite connue : la reconnaissance repose sur des noms de fonctions et de variables courants ; un test de tendances écrit autrement échappe à la règle, qui peut alors signaler à tort. Elle ne distingue pas une double différence d'une autre régression qui cite le traitement.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

