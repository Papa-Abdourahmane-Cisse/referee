# ECO-01 : Erreurs standards non robustes à la structure de grappes

**Famille** : ECO (Économétrie et identification)  
**Niveaux de confiance** : risque probable  
**Détection** : statique, métadonnées  
**Entrées requises** : un script R ; métadonnées : `cluster`

## Ce que la règle détecte

Quand une variable de grappe est déclarée (panel, observations groupées), signale les régressions `lm()`, `glm()`, `plm()` et `ivreg()` si aucun ajustement des erreurs standards pour les grappes n'apparaît dans le script (`vcovCL()`, `vcovCR()`, argument `cluster`, `clusters` ou `vcov`, plan de sondage). Une correction robuste à l'hétéroscédasticité seule (`vcovHC()`) ne tient pas compte des grappes.
La nécessité de regrouper dépend du plan d'échantillonnage et de l'assignation du traitement : la règle demande une justification, elle ne tranche pas. Limite connue : un seul ajustement en grappes n'importe où dans le script suffit à la faire taire. Les régressions `feols()` et `felm()` ne sont pas signalées : leurs erreurs standards par défaut dépendent de la version et des effets fixes.

## Pourquoi c'est un problème

Les erreurs d'observations corrélées au sein d'une grappe (village, individu suivi dans le temps) sous-estiment la variance si elles sont traitées comme indépendantes.

## Que faire en cas d'alerte

Regrouper les erreurs standards au niveau où le traitement est assigné ou échantillonné (`vcovCL()`, `lm_robust(clusters = )`, `feols(cluster = )`) ; justifier le niveau de regroupement. Note : la règle n'examine pas `feols()` ni `felm()`, et le traitement par défaut des erreurs standards de `feols()` dépend de la version de `fixest` : déclarer explicitement `vcov = ~village` plutôt que de s'en remettre au défaut.

## Exemple

```r
lm(y ~ x, data = d)   # alerte
estimatr::lm_robust(y ~ x, data = d, clusters = village)
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R",
                  meta = referee_meta(cluster = "village"))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

