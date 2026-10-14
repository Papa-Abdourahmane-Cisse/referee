# SUR-01 : Estimateur sans poids alors qu'une variable de poids est déclarée

**Famille** : SUR (Plan de sondage et pondération)  
**Niveaux de confiance** : risque probable  
**Détection** : statique, métadonnées  
**Entrées requises** : un script R ; métadonnées : `weights`

## Ce que la règle détecte

Signale les appels à des estimateurs usuels (`mean`, `lm`, etc.) dont les arguments ne citent ni la variable de poids ni un argument `weights`. Les variantes pondérées (`weighted.mean`, `svymean`) ne sont pas concernées.
Les pipes magrittr (`%>%`) sont dépliés et les appels situés dans un verbe de manipulation de table (`summarise()`, `mutate()`, etc.) sont rattachés à la table de départ : `enes %>% summarise(m = mean(x))` est reconnu comme un calcul sur `enes`.

## Pourquoi c'est un problème

Une enquête par sondage sur-représente ou sous-représente certaines unités ; une moyenne non pondérée estime la population de l'échantillon, pas celle du pays. Le biais dépend de la corrélation entre le poids et la variable étudiée.

## Que faire en cas d'alerte

Si la table est une enquête : utiliser `survey::svymean()`, `weighted.mean()` ou `srvyr::summarise()` sur un plan déclaré. Si la moyenne non pondérée est voulue (contrôle de qualité de l'échantillon, par exemple), la libeller comme telle. Si la table n'est pas une enquête (recensement, table agrégée), déclarer `data_objects` pour que la règle ne l'examine pas.

## Exemple

```r
mean(enq$emploi)   # alerte
survey::svymean(~emploi, plan)   # correct
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R",
                  meta = referee_meta(weights = "poids"))
rapport
```

## Limites connues

Limite connue : un appel qui cite la variable de poids sans l'utiliser comme poids (par exemple pour filtrer) échappe à la règle. Un objet intermédiaire (`d2 <- enes %>% filter(...)`, puis `mean(d2$x)`) n'est pas relié à `enes`.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

