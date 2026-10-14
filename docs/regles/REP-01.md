# REP-01 : Chemin absolu propre à une machine, ou fichier d'entrée introuvable

**Famille** : REP (Reproductibilité)  
**Niveaux de confiance** : certitude, risque probable  
**Détection** : statique, système de fichiers  
**Entrées requises** : un script R

## Ce que la règle détecte

Examine les chemins écrits en toutes lettres dans les appels de lecture (`read.csv()`, `read_dta()`, `readRDS()`, etc.), d'écriture (`write.csv()`, `saveRDS()`, etc.) et dans `setwd()`. Un chemin absolu (`/home/...`, `C:/...`, `~/...`) est un risque probable : il ne fonctionnera pas sur une autre machine. Un fichier d'entrée relatif qui n'existe pas dans `project_dir` est un constat de certitude. Si `project_dir` n'est pas fourni, l'existence des fichiers relatifs n'est pas contrôlée. L'existence d'un chemin absolu n'est pas contrôlée non plus : l'audit ne s'exécute pas forcément sur la machine de l'analyse.
Les chemins construits par `paste0()`, `paste()` ou `file.path()` à partir de chaînes littérales et de variables affectées au premier niveau du script sont reconstitués sans exécuter le code ; pour un chemin partiellement connu, seul le début est examiné (chemin absolu), pas l'existence du fichier.

## Pourquoi c'est un problème

Un chemin absolu (`C:/Users/...`) ne fonctionne que sur la machine de l'auteur : le script n'est pas reproductible par un tiers.

## Que faire en cas d'alerte

Utiliser des chemins relatifs à la racine du projet (`here::here('data', 'a.csv')`, projet RStudio) et regrouper les chemins en tête de script.

## Exemple

```r
read.csv('C:/Users/moi/a.csv')   # alerte
read.csv(here::here('data', 'a.csv'))
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R")
rapport
```

## Limites connues

Limite connue : un chemin issu d'une fonction (`here::here()`, `getwd()`, une variable lue ailleurs) n'est pas évalué. Les adresses web sont ignorées.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

