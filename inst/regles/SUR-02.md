# SUR-02 : Poids ménage divisé par la taille du ménage

**Famille** : SUR (Plan de sondage et pondération)  
**Niveaux de confiance** : risque probable  
**Détection** : statique, métadonnées  
**Entrées requises** : un script R ; métadonnées : `weights`, `size`

## Ce que la règle détecte

Détecte l'expression `poids / taille`. Pour un indicateur individuel calculé sur une enquête ménages, le poids individuel est généralement le poids du ménage multiplié par sa taille (chaque ménage répliqué autant de fois que de membres, avec son poids complet). La convention exacte dépend de la documentation de chaque enquête : la règle alerte, elle ne tranche pas.

## Pourquoi c'est un problème

Dans plusieurs enquêtes ménages, le poids individuel s'obtient en multipliant le poids du ménage par sa taille. Le diviser par la taille donne des effectifs et des taux faux pour les indicateurs individuels.

## Que faire en cas d'alerte

Consulter la documentation de l'enquête pour la convention exacte du poids. La règle alerte sur la division `poids / taille` ; elle ne dit pas que la convention de votre enquête est l'inverse.

## Exemple

```r
poids_ind <- poids_men / taille_men   # alerte
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R",
                  meta = referee_meta(weights = "poids", size = "taille_men"))
rapport
```

## Limites connues

Limite connue : seule la division écrite dans le script est détectée, pas l'usage du poids ménage tel quel sur un indicateur individuel.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

