# DEM-02 : Équation compensatrice non respectée

**Famille** : DEM (Démographie (règles candidates))  
**Niveaux de confiance** : certitude  
**Détection** : données, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `balance`

> Règle candidate, non relue par un démographe : à utiliser avec prudence.

## Ce que la règle détecte

Pour chaque ligne (zone, période), vérifie `P1 = P0 + naissances - décès + immigrants - émigrants`, à une tolérance près. Si les migrations ne sont pas déclarées, la population est supposée fermée, et le message le dit. Les lignes où une composante manque sont ignorées. Un écart au-delà de la tolérance est un constat de certitude : l'identité déclarée n'est pas satisfaite.

## Pourquoi c'est un problème

La population finale doit égaler la population initiale plus les naissances moins les décès plus le solde migratoire ; un écart indique une erreur de saisie, de calcul ou une composante mal estimée.

## Que faire en cas d'alerte

Rechercher la composante en cause ; si l'écart est un résidu de mesure légitime, régler la tolérance et le documenter. Règle candidate : à faire relire.

## Exemple

```r
referee_meta(balance = list(p0 = 'pop0', p1 = 'pop1', births = 'nais', deaths = 'deces'))
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(balance = list(p0 = "pop0", p1 = "pop1", births = "nais", deaths = "deces")))
rapport
```

## Limites connues

Ce que la règle ne dit pas : si l'écart vient d'une erreur de saisie, d'un calcul ou d'un résidu de mesure légitime (composantes estimées séparément). La tolérance est donc à choisir selon la source.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

