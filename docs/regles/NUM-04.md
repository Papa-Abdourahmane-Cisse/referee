# NUM-04 : Codes de valeurs manquantes traités comme des valeurs

**Famille** : NUM (Cohérence numérique)  
**Niveaux de confiance** : risque probable  
**Détection** : données  
**Entrées requises** : des données (data frame)

## Ce que la règle détecte

Pour chaque colonne numérique, signale la présence d'un code usuel de valeur manquante (99, 999, 9999, ... ou leurs opposés) lorsqu'il se détache nettement des autres valeurs : supérieur ou égal à `factor` fois le maximum des autres valeurs, ou négatif alors que toutes les autres sont positives ou nulles. Un 99 dans une colonne d'âges qui monte légitimement à 98 n'est donc pas signalé. Risque probable : seule la documentation du questionnaire tranche.

## Pourquoi c'est un problème

Un code comme 99 ou 9999 traité comme une valeur fausse moyennes, variances et régressions.

## Que faire en cas d'alerte

Consulter le questionnaire et le dictionnaire de variables ; recoder en `NA` les codes de non-réponse avant calcul. Un code qui est une valeur réelle (âge 99) se justifie.

## Exemple

```r
d$age[d$age == 99] <- NA   # si 99 est un code de non-réponse
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees)
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

