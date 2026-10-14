# DEM-04 : Rapport de masculinité hors d'une plage plausible

**Famille** : DEM (Démographie (règles candidates))  
**Niveaux de confiance** : à justifier  
**Détection** : données, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `sexratio`

> Règle candidate, non relue par un démographe : à utiliser avec prudence.

## Ce que la règle détecte

Calcule, par groupe d'âges, le nombre d'hommes pour 100 femmes, soit à partir de microdonnées (variable de sexe et modalité masculine, avec poids si fournis), soit à partir d'effectifs agrégés. Signale les groupes dont le rapport sort de `range`. Les groupes comptant moins de `min_n` observations (non pondérées, par sexe) sont ignorés.
La plage par défaut (80 à 120) est indicative et à calibrer : des migrations de travail, des conflits ou des décalages de couverture produisent des rapports atypiques légitimes. Un rapport atypique n'est pas une erreur en soi : il est à justifier.

## Pourquoi c'est un problème

Un rapport de masculinité très éloigné de 100 dans un groupe d'âges peut indiquer une omission sélective au recensement ou à l'enquête, ou un biais de déclaration ; il peut aussi refléter des migrations de travail.

## Que faire en cas d'alerte

Justifier ou corriger selon le contexte ; la plage par défaut (80 à 120) est indicative. Règle candidate : à faire relire.

## Exemple

```r
referee_meta(sexratio = list(group = 'groupe_age', males = 'hommes', females = 'femmes'))
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(sexratio = list(group = "groupe_age", males = "hommes", females = "femmes")))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

