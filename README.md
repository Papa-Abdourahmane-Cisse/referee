# referee : détecteur d'erreurs méthodologiques pour statisticiens et économistes

Version de travail (`0.0.0.9000`). Le paquet applique des règles déterministes
à un jeu de données, à un script R et à des métadonnées déclarées, puis produit
un rapport de constats classés par niveau de confiance :
`certitude`, `risque_probable`, `a_justifier`.

**L'absence d'alerte ne vaut pas validation.** Une règle dont les entrées sont
manquantes est rapportée « non évaluée », jamais comme réussie.

## Règles implémentées (34)

| Famille | Règles |
|---|---|
| SUR : plan de sondage et pondération | SUR-01 à SUR-04 |
| LVL : niveaux d'analyse | LVL-01 à LVL-03 |
| NUM : cohérence numérique | NUM-01 à NUM-04 |
| VAL : validation en apprentissage automatique | VAL-01 à VAL-06 (VAL-07 non implémentée : détectabilité trop faible) |
| ECO : économétrie et identification | ECO-01 à ECO-05 |
| EXT : cohérence externe | EXT-01, EXT-02 |
| REP : reproductibilité | REP-01 à REP-03 |
| DOC : cohérence documentaire | DOC-01 à DOC-03 |
| DEM : démographie (règles candidates, non relues par un praticien) | DEM-01 à DEM-04 |

Le catalogue neutre (indépendant du langage) est dans `inst/catalogue/rules.yml`.
Certains seuils (dispersion des poids, codes de valeurs manquantes, parts
d'échelles mélangées) sont des conventions de pratique, pas des résultats
établis : ils sont paramétrables.

## Installation et usage

```r
# install.packages("remotes")
remotes::install_local(".")   # depuis la racine du dépôt

library(referee)
meta <- referee_meta(weights = "hhweight", size = "hhsize")
rapport <- audit(data = mes_donnees, script = "analyse.R", meta = meta)
rapport
```

## Tests et vérification

```r
devtools::test()    # tests testthat
devtools::check()   # R CMD check
```

Chaque règle a un test positif (erreur injectée sur données simulées) et une
« jumelle négative » (version correcte qui ne doit pas déclencher d'alerte).
Les messages sont en français : les tests qui comparent du texte accentué sont
ignorés dans une locale non UTF-8.

## Intégration continue

`.github/workflows/R-CMD-check.yaml` exécute `R CMD check` sur Linux, macOS et
Windows à chaque `push` et pull request vers `main`. Tout avertissement fait
échouer la vérification.

## Limites connues

Références du catalogue à vérifier. Aucune validation sur de vrais scripts ou de vraies données n'a encore été faite.

## Licence

GPL-3 (voir `COPYING`). Auteur : Papa Abdourahmane Cissé.
