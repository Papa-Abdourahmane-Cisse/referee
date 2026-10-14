# DOC-03 : Langage causal sans design d'identification déclaré

**Famille** : DOC (Cohérence documentaire)  
**Niveaux de confiance** : à justifier  
**Détection** : texte, métadonnées  
**Entrées requises** : un document texte ; métadonnées : `design`

## Ce que la règle détecte

Si le design déclaré (`design`) n'est pas un design d'identification reconnu (expérience aléatoire, double différence, discontinuité de régression, variables instrumentales, appariement, contrôle synthétique), signale les lignes du texte qui emploient un vocabulaire causal (« l'effet de », « l'impact de », « entraîne », « grâce à », « a permis de », etc.). La règle ne vérifie pas que le design déclaré est valide : un design déclaré suffit à la faire taire. Un vocabulaire causal sans design d'identification est à justifier ou à reformuler (« est associé à »).

## Pourquoi c'est un problème

Un vocabulaire causal (« l'effet de », « grâce à ») sans design d'identification confond association et causalité.

## Que faire en cas d'alerte

Reformuler (« est associé à ») ou déclarer et justifier un design d'identification (expérience, DID, RDD, VI, appariement, contrôle synthétique).

## Exemple

```r
'L'effet du programme est de +5 points'   # alerte sans design
```

## Utilisation

```r
library(referee)
rapport <- audit(document = "rapport.md",
                  meta = referee_meta(design = "double différence"))
rapport
```

## Limites connues

Limites : détection purement lexicale. « L'impact de la sécheresse » dans un contexte descriptif est signalé ; une formulation causale sans ces mots échappe à la règle.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

