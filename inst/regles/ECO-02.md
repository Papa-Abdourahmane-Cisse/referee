# ECO-02 : Double différence à effets fixes bidirectionnels avec adoption échelonnée

**Famille** : ECO (Économétrie et identification)  
**Niveaux de confiance** : risque probable  
**Détection** : statique, données, métadonnées  
**Entrées requises** : des données (data frame) ; un script R ; métadonnées : `unit`, `time`, `treat`

## Ce que la règle détecte

Établit à partir des données que les unités adoptent le traitement à des dates différentes (au moins deux dates d'adoption distinctes, hors unités traitées dès la première période), puis signale les régressions à effets fixes d'unité et de période (`feols()`, `felm()`, `plm()`, `lm()` avec facteurs) qui citent le traitement, l'unité et le temps, en l'absence d'estimateur robuste à l'hétérogénéité des effets dans le script (`att_gt()`, `did_imputation()`, `sunab()`, etc.).
Le fait (adoption échelonnée) est établi par les données ; le biais ne l'est pas : il suppose des effets de traitement hétérogènes dans le temps ou entre cohortes. D'où un risque probable. Limites : un traitement qui s'arrête puis reprend n'est pas traité spécifiquement ; une régression qui cite les trois variables sans être à effets fixes bidirectionnels peut être signalée à tort ; le temps est ordonné par ses valeurs (une période codée en texte est ordonnée alphabétiquement).

## Pourquoi c'est un problème

Avec adoption échelonnée du traitement et effets hétérogènes, l'estimateur à effets fixes bidirectionnels combine des comparaisons dont certaines utilisent des unités déjà traitées comme contrôle, et peut être biaisé, y compris de signe inverse.

## Que faire en cas d'alerte

Utiliser un estimateur robuste à l'hétérogénéité (`did::att_gt()`, `did2s`, `sunab()`, `did_imputation`) et présenter l'étude d'événement.

## Exemple

```r
feols(y ~ traite | unite + annee, data = d)   # alerte si adoption échelonnée
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  script = "analyse.R",
                  meta = referee_meta(unit = "village", time = "annee", treat = "traite"))
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

