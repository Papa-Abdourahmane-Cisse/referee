# ECO-04 : Instrument faible : statistique F de première étape sous le seuil indicatif

**Famille** : ECO (Économétrie et identification)  
**Niveaux de confiance** : risque probable  
**Détection** : données, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `endog`, `instruments`

## Ce que la règle détecte

Calcule la statistique F de première étape : test de Fisher de la nullité conjointe des coefficients des instruments dans la régression de la variable endogène sur les instruments et les contrôles (mêmes lignes complètes). Signale un F inférieur au seuil.
Le calcul est exact ; sa lecture ne l'est pas. Le seuil de 10 est une règle empirique à réexaminer, pas un critère universel. Ce F suppose des erreurs homoscédastiques et indépendantes : avec grappes ou hétéroscédasticité, un F robuste (par exemple le F effectif) est plus approprié. Avec plusieurs instruments ou plusieurs régresseurs endogènes, le seuil de 10 n'est pas un critère adéquat. Les pondérations ne sont pas appliquées. Cette règle ne teste ni la validité (exclusion) ni l'exogénéité de l'instrument. Le catalogue v0 la classe « certitude (calcul) » ; le paquet retient « risque probable », car la faiblesse de l'instrument est une conclusion, pas le calcul.

## Pourquoi c'est un problème

Un instrument faiblement corrélé au régresseur endogène produit un estimateur biaisé vers MCO et des tests déformés.

## Que faire en cas d'alerte

Rapporter le F de première étape adapté à la structure d'erreurs (F robuste ou F effectif en cas d'hétéroscédasticité ou de grappes) et des intervalles de confiance robustes à un instrument faible (Anderson-Rubin).

## Exemple

```r
# F de première étape inférieur au seuil indicatif : alerte
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(endog = "x_endogene", instruments = "z"))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

