# SUR-04 : Poids invalides (manquants, négatifs, nuls, dispersion extrême)

**Famille** : SUR (Plan de sondage et pondération)  
**Niveaux de confiance** : certitude, à justifier  
**Détection** : données  
**Entrées requises** : des données (data frame) ; métadonnées : `weights`

## Ce que la règle détecte

Constats de certitude : poids manquants, infinis ou négatifs. Constats à justifier : poids nuls (observations exclues de toute estimation pondérée) et dispersion extrême, mesurée par le rapport du maximum à la médiane des poids strictement positifs. Le seuil de dispersion est une convention de pratique, pas un résultat établi : à calibrer selon l'enquête.

## Pourquoi c'est un problème

Des poids manquants, négatifs ou infinis rendent les estimations pondérées indéfinies ou fausses ; des poids très dispersés rendent les estimations instables (effet de plan élevé).

## Que faire en cas d'alerte

Rechercher l'origine des poids invalides (jointure incomplète, calage non fait). Pour la dispersion, comparer à la distribution des poids de la documentation de l'enquête et examiner l'effet sur l'estimation (avec/sans troncature).

## Exemple

```r
summary(d$poids)   # contrôler min, max, NA
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(weights = "poids"))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

