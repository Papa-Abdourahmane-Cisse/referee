# DEM-01 : Préférence pour les âges se terminant par 0 ou 5 (indice de Whipple)

**Famille** : DEM (Démographie (règles candidates))  
**Niveaux de confiance** : à justifier  
**Détection** : données, métadonnées  
**Entrées requises** : des données (data frame) ; métadonnées : `age`

> Règle candidate, non relue par un démographe : à utiliser avec prudence.

## Ce que la règle détecte

Calcule l'indice de Whipple : 100 fois le rapport entre l'effectif des personnes de 23 à 62 ans dont l'âge déclaré se termine par 0 ou 5 et le cinquième de l'effectif total de cette tranche d'âges (soit 500 fois la part des âges terminant par 0 ou 5). Il vaut 100 sans préférence pour ces chiffres et 500 si tout le monde les déclare. Les âges sont comptés avec les poids si une variable de poids est fournie ; le contrôle de l'effectif minimal porte sur les observations non pondérées. Un indice supérieur ou égal au seuil est un constat à justifier.

## Pourquoi c'est un problème

L'attraction pour les âges se terminant par 0 ou 5 trahit des déclarations d'âge arrondies, qui faussent pyramides, taux par âge et projections.

## Que faire en cas d'alerte

Si l'indice est élevé, utiliser des groupes d'âges quinquennaux ou lisser (méthodes de la littérature démographique) et le signaler. Règle candidate : à faire relire par un démographe.

## Exemple

```r
referee_meta(age = 'age')
```

## Utilisation

```r
library(referee)
rapport <- audit(data = mes_donnees,
                  meta = referee_meta(age = "age"))
rapport
```

## Limites connues

Limites : l'indice suppose une distribution des âges assez régulière entre 23 et 62 ans ; une pyramide très décroissante ou des migrations sélectives le déforment. Il ne détecte que la préférence pour 0 et 5, pas les autres attractions. L'indice de Myers n'est pas implémenté. Le seuil par défaut (125) est celui où l'échelle usuelle passe à une qualité « grossière » ; c'est une convention. Le contrôle s'applique à des âges en années révolues, saisis en entiers : sinon, la règle est non évaluée.

Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.

