# DOC-02 : Indicateur chiffré de deux façons, ou sans niveau géographique ni période

**Famille** : DOC (Cohérence documentaire)  
**Niveaux de confiance** : risque probable, à justifier  
**Détection** : texte, métadonnées  
**Entrées requises** : un document texte ; métadonnées : `indicators`

## Ce que la règle détecte

Pour chaque indicateur déclaré (`indicators`, avec un motif qui le repère), relève les chiffres qui le suivent dans le texte. Deux contrôles. (1) Des chiffres différents pour le même indicateur dans des phrases qui partagent les mêmes années et les mêmes termes géographiques déclarés (`geo_terms`) : risque probable, car le texte désigne alors la même population et la même période. (2) Un indicateur chiffré dans une phrase sans année ni terme géographique : constat à justifier.

## Pourquoi c'est un problème

Un même indicateur chiffré de deux façons pour la même population et la même période, ou sans niveau géographique ni période, est ambigu pour le lecteur.

## Que faire en cas d'alerte

Conserver une seule valeur de référence par indicateur ; préciser systématiquement le niveau géographique et la période.

## Exemple

```r
referee_meta(indicators = list(list(name = 'pauvreté', pattern = 'pauvret')), geo_terms = c('national', 'Dakar'))
```

## Utilisation

```r
library(referee)
rapport <- audit(document = "rapport.md",
                  meta = referee_meta(indicators = list(list(name = "pauvreté", pattern = "pauvret"))))
rapport
```

## Limites connues

Limites : la règle ne compare pas les définitions ; elle ne reconnaît que les années et les termes géographiques déclarés ; les périodes autres que des années (« premier semestre ») ne sont pas vues ; le contrôle (2) est bruyant dans une introduction ou un résumé.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

