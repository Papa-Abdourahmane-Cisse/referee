# DEM-03 : Table de mortalité incohérente (qx hors de [0 ; 1], lx croissant)

**Famille** : DEM (Démographie (règles candidates))  
**Niveaux de confiance** : certitude  
**Détection** : données, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `lifetable`

> Règle candidate, non relue par un démographe : à utiliser avec prudence.

## Ce que la règle détecte

Deux contrôles de certitude : une probabilité de décès `qx` hors de [0 ; 1], et un nombre de survivants `lx` qui augmente avec l'âge. Les lignes sont ordonnées par âge, par table si `by` est fourni ; les valeurs manquantes sont ignorées. La règle ne contrôle ni l'égalité `l(x+n) = l(x) (1 - nqx)` ni le niveau des espérances de vie.

## Pourquoi c'est un problème

Une probabilité de décès hors de [0 ; 1] ou des survivants qui augmentent avec l'âge sont impossibles dans une table de mortalité.

## Que faire en cas d'alerte

Contrôler la saisie, l'ordre des âges et le groupe de table. Règle candidate : à faire relire.

## Exemple

```r
referee_meta(lifetable = list(age = 'age', qx = 'qx', lx = 'lx'))
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(lifetable = list(age = "age", qx = "qx")))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

