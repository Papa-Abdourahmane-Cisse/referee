# REP-03 : Environnement logiciel non documenté (ni renv.lock, ni Dockerfile, ni sessionInfo)

**Famille** : REP (Reproductibilité)  
**Niveaux de confiance** : à justifier  
**Détection** : système de fichiers  
**Entrées requises** : un dossier de projet

## Ce que la règle détecte

Cherche dans `project_dir` un fichier de verrouillage des versions (`renv.lock`, `packrat.lock`), un `Dockerfile` ou une sortie de `sessionInfo()` enregistrée (nom de fichier contenant `sessionInfo` ou `session_info`). Aucun de ces éléments : constat à justifier. La présence d'un fichier n'établit pas qu'il est à jour.

## Pourquoi c'est un problème

Sans trace des versions de R et des paquets, les résultats peuvent changer d'une machine ou d'une date à l'autre.

## Que faire en cas d'alerte

Verrouiller l'environnement (`renv::init()`, `renv.lock`), ou fournir un `Dockerfile`, ou enregistrer `sessionInfo()`.

## Exemple

```r
renv::init(); renv::snapshot()
```

## Utilisation

```r
library(referee)
rapport <- audit(project_dir = ".")
rapport
```

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

