# REP-04 : Fonction d'un paquet appelée sans que le paquet soit chargé

**Famille** : REP (Reproductibilité)  
**Niveaux de confiance** : risque probable  
**Détection** : statique  
**Entrées requises** : un script R

## Ce que la règle détecte

Signale l'appel de premier niveau d'une fonction connue pour appartenir à un paquet (`ca.jo()` pour `urca`, `as.yearqtr()` pour `zoo`, `read_excel()` pour `readxl`, `svydesign()` pour `survey`, etc.) lorsque le script ne charge pas ce paquet avant l'appel, ne le préfixe pas (`urca::ca.jo()`) et ne définit pas lui-même la fonction. L'exécution s'arrêterait sur « could not find function ». Les paquets attachés en cascade (`library(vars)` attache `urca`, par exemple) sont pris en compte par une table fixe.

## Pourquoi c'est un problème

Un script qui appelle `ca.jo()` sans charger `urca` s'arrête sur « could not find function » chez un tiers, et parfois chez son auteur dès qu'une session est redémarrée : il dépendait d'un paquet chargé auparavant à la main.

## Que faire en cas d'alerte

Charger chaque paquet utilisé en tête de script (`library(urca)`), ou préfixer l'appel (`urca::ca.jo()`). Documenter l'environnement (REP-03).

## Exemple

```r
ca.jo(d)            # alerte
library(urca)
ca.jo(d)
```

## Utilisation

```r
library(referee)
rapport <- audit(script = "analyse.R")
rapport
```

## Limites connues

Limites connues : la liste des fonctions reconnues est courte et ne couvre pas tous les paquets ; un paquet chargé hors du script (fichier `.Rprofile`, script appelé par `source()`) n'est pas vu, d'où le niveau « risque probable » ; la table des paquets attachés en cascade est volontairement prudente mais incomplète, et un paquet absent de la table qui attache lui-même d'autres paquets peut provoquer un faux positif. Si le script charge des paquets de façon dynamique (`character.only = TRUE`, boucle sur `library`), la règle est non évaluée.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

