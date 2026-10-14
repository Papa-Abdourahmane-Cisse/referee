# EXT-02 : Ligne de pauvreté, année, unité ou période incohérentes avec l'agrégat de bien-être déclaré

**Famille** : EXT (Cohérence externe)  
**Niveaux de confiance** : risque probable  
**Détection** : métadonnées  
**Entrées requises** : des métadonnées seules ; métadonnées : `poverty`

## Ce que la règle détecte

Contrôle uniquement des métadonnées déclarées : année de la ligne de pauvreté (`line_year`) et de l'agrégat de bien-être (`welfare_year`), si l'agrégat a été ajusté des prix à l'année de la ligne (`price_adjusted`), unité de comptage (`line_unit` et `welfare_unit`, par exemple « par tête » ou « par équivalent adulte ») et période (`line_period` et `welfare_period`, par exemple « jour » ou « an »). Une incohérence entre deux déclarations est un risque probable ; la règle ne vérifie ni la valeur de la ligne ni la qualité du déflateur, et elle n'est pas évaluée si aucune paire de déclarations n'est comparable.

## Pourquoi c'est un problème

Comparer une ligne de pauvreté et un agrégat de consommation qui n'ont pas la même année de prix, la même unité (par tête, par équivalent adulte) ou la même période (jour, an) donne un taux de pauvreté faux.

## Que faire en cas d'alerte

Harmoniser l'année (déflateur), l'unité et la période, ou justifier la correspondance dans la méthodologie.

## Exemple

```r
referee_meta(poverty = list(line_year = 2018, welfare_year = 2021, price_adjusted = FALSE))
```

## Utilisation

```r
library(referee)
rapport <- audit(meta = referee_meta(poverty = list(line_year = 2018, welfare_year = 2021, price_adjusted = FALSE)))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

