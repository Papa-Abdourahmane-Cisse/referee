# LVL-01 : Désagrégation artificielle d'une valeur de niveau supérieur

**Famille** : LVL (Niveaux d'analyse)  
**Niveaux de confiance** : certitude  
**Détection** : données, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `group`, `group_vars`

## Ce que la règle détecte

Pour chaque variable de `vars`, vérifie si elle est constante au sein de chaque unité de `group` alors qu'elle varie entre unités : c'est la signature d'une valeur de niveau supérieur dupliquée sur des unités plus fines (une valeur régionale répétée sur les communes, par exemple).
Le constat est certain (les valeurs sont identiques), sa gravité ne l'est pas : une variable contextuelle régionale utilisée comme prédicteur est défendable, la même variable utilisée comme cible ne l'est pas. L'égalité est exacte : une valeur dupliquée puis arrondie différemment n'est pas vue.

## Pourquoi c'est un problème

Une valeur régionale répétée sur des communes n'est pas une observation communale indépendante : la taille d'échantillon apparente est surestimée et un modèle peut « apprendre » la région plutôt que la commune.

## Que faire en cas d'alerte

Distinguer la variable utilisée comme prédicteur contextuel (défendable, avec erreurs standards groupées au niveau régional) de la variable utilisée comme cible (à éviter). Documenter l'hypothèse de désagrégation.

## Exemple

```r
# taux_region identique pour toutes les communes d'une région : alerte
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(group = "region", group_vars = "taux"))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

