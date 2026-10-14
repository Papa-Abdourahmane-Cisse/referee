# Contribuer

## Signaler un faux positif ou un faux négatif

Ouvrez une *issue* avec : (1) un extrait de script **minimal** qui reproduit le
cas (sans données confidentielles), (2) la règle concernée, (3) ce que vous
attendiez, (4) ce que le paquet a rapporté, (5) la sortie de `sessionInfo()`.

## Proposer une règle

Une règle doit : être déterministe ; avoir un niveau de confiance justifié ;
déclarer ce qu'elle ne détecte pas ; être livrée avec un test positif (erreur
injectée) et une « jumelle négative » (version correcte sans alerte) ; avoir sa
conduite à tenir dans `tools/conduite.R`. Elle ne doit pas affirmer plus que ce
que le code ou les données établissent.

## Développement

```r
devtools::load_all()
devtools::test()
roxygen2::roxygenise()                 # après modification de la documentation
source("tools/build_docs.R")           # régénère docs/regles et inst/regles
```

Les tests qui comparent du texte accentué sont ignorés dans une locale non
UTF-8 : exécutez-les avec `LC_ALL=C.UTF-8` (Linux, macOS).

## Références

Ne citez que des références vérifiées (DOI contrôlé). Mettez à jour
`docs/references.md`.
