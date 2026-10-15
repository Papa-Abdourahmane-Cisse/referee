# referee 0.2.0

* 36 règles. Nouvelle famille **SER** (séries temporelles) avec `SER-01` :
  test de racine unitaire ou de stationnarité (`adf.test()`, `ur.df()`,
  `pp.test()`, `kpss.test()`...) appliqué aux résidus d'une régression `lm()`
  entre séries, cas du test de cointégration d'Engle-Granger avec des valeurs
  critiques inadaptées.
* Nouvelle règle `REP-04` : fonction d'un paquet (`ca.jo()`, `as.yearqtr()`,
  `read_excel()`, `svydesign()`...) appelée sans que le paquet soit chargé ;
  les paquets attachés en cascade (`library(vars)` attache `urca` et `zoo`)
  sont pris en compte par une table fixe.
* Ces deux règles viennent d'un premier test sur des scripts indépendants
  (voir `docs/validation.md`), où le moteur de la version 0.1.0 ne détectait
  aucune de ces erreurs.
* Exemple `inst/examples/cointegration_fautive.R`.

# referee 0.1.0

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
