# SUR-03 : Variance estimée sans le plan de sondage (strates, grappes) ou plan sans grappe

**Famille** : SUR (Plan de sondage et pondération)  
**Niveaux de confiance** : risque probable, à justifier  
**Détection** : statique, métadonnées  
**Entrées requises** : un script R

## Ce que la règle détecte

Quand des strates ou des grappes sont déclarées, signale les régressions et tests de base R appelés sans qu'aucun plan de sondage (`svydesign`, `as_survey_design`, etc.) ne soit défini dans le script.
Indépendamment des métadonnées, signale aussi un plan construit sans grappe (`svydesign(ids = ~1, ...)`) : confiance « à justifier » (le tirage peut réellement être sans grappe, ou les grappes peuvent être absentes de la base), et « risque probable » si une grappe est déclarée dans `psu`.

## Pourquoi c'est un problème

Les erreurs standards d'un tirage en grappes ou stratifié diffèrent de celles d'un tirage aléatoire simple. Ignorer les grappes sous-estime en général la variance, donc surestime la précision et le nombre de résultats « significatifs ». Un plan construit avec `ids = ~1` traite chaque unité comme indépendante.

## Que faire en cas d'alerte

Déclarer les grappes et les strates dans `svydesign(ids = ~grappe, strata = ~strate, ...)`. Si le tirage est réellement sans grappe, ou si les grappes ne figurent pas dans la base publiée, le justifier dans le texte (avec une mention de l'effet de plan attendu).

## Exemple

```r
svydesign(ids = ~1, weights = ~poids, data = d)   # alerte (à justifier)
svydesign(ids = ~grappe, strata = ~strate, weights = ~poids, data = d, nest = TRUE)
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R")
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

