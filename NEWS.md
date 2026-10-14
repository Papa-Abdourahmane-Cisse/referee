# referee 0.0.0.9000

* 34 règles : SUR, LVL, NUM, VAL, ECO, EXT, REP, DOC, DEM (règles DEM à faire
  relire par un démographe).
* `audit_script()` : audit d'un script en une commande, avec lecture des
  métadonnées déclarées par `svydesign()` (`infer_meta()`, `audit(infer = )`).
* Analyse statique : les pipes `%>%` sont dépliés et les appels de
  `summarise()`, `mutate()`, etc. sont rattachés à leur table de départ.
* SUR-03 signale aussi un plan de sondage construit sans grappe
  (`svydesign(ids = ~1)`), sans métadonnée.
* REP-01 reconstitue les chemins passés par une variable (`paste0()`,
  `file.path()`).
* `explain_rule()` affiche la fiche d'une règle ; fiches dans `docs/regles/`.
