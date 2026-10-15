# Validation : ce qui a été mesuré, ce qui ne l'a pas été

## Tests automatisés

Chaque règle a un test positif (erreur injectée sur données simulées) et une
« jumelle négative » (version correcte qui ne doit pas déclencher d'alerte).
Ces tests établissent que les règles font ce qu'elles annoncent sur des cas
construits pour elles. Ils n'établissent rien sur des scripts réels.

## Essai sur un script réel (un seul)

Un script d'estimation sur petits domaines (Fay-Herriot, enquête emploi, 47
départements, environ 1 000 lignes de code) a été audité sans le modifier.
Le jugement « fondé » ou « faux positif » est celui d'un seul relecteur
(l'auteur du paquet, avec l'assistance de Claude), non indépendant de la
conception des règles.

| Configuration | Constats | Lecture |
|---|---|---|
| script seul | 0 (2 règles évaluées) | un chemin absolu à la ligne 26 échappe à REP-01 dans cette version initiale |
| `weights` déclaré | 30 (tous SUR-01) | 6 fondés, 24 faux positifs (recensement, tables agrégées) |
| `weights` + `data_objects`, avant suivi du pipe | 1 | 5 des 6 constats fondés perdus (faux négatifs) |
| `audit_script()` (inférence + suivi du pipe, version actuelle) | 9 | 6 SUR-01 fondés, 1 SUR-03 à justifier, 2 REP-01 fondés ; aucun faux positif parmi les 9 |

**Biais à garder en tête.** Les améliorations du moteur (suivi du pipe,
inférence de la table d'enquête, chemins en variable, `ids = ~1`) ont été
conçues **après** l'examen de ce script. La dernière ligne du tableau mesure
donc un réglage sur ce script, pas une performance attendue ailleurs.

Parmi les 6 constats SUR-01 fondés, deux (lignes 88 et 300) portent sur des
taux libellés « brut » dans le script : le calcul n'est pas pondéré, mais le
libellé est explicite ; quatre (ligne 349) alimentent le modèle de
Fay-Herriot avec des covariables non pondérées, ce qui est plus lourd de
conséquences.

## Cinq scripts d'exemple (écrits pour l'occasion)

Les scripts de `inst/examples/` ont été écrits par l'auteur des règles en
sachant ce qu'elles détectent. Ils servent de test de non-régression, pas de
validation indépendante.

| Script | Attendu | Observé |
|---|---|---|
| `enquete_propre.R` | aucune alerte | aucune alerte |
| `enquete_fautive.R` | 3 SUR-01, 1 SUR-03, 2 REP-01 ; le recensement non signalé | conforme |
| `ml_fuite.R` | VAL-01, VAL-02, VAL-03, REP-02 | conforme (VAL-04 évaluée, sans alerte) |
| `did_fautif.R` | ECO-03 | conforme ; ECO-01 évaluée sans alerte (ECO-01 n'examine pas `feols()`) ; ECO-02 non évaluée (il faut les données) |
| `cointegration_fautive.R` | 2 SER-01 (`adf.test`, `kpss.test`), 1 REP-04 | conforme |

## Premier corpus indépendant (15 octobre 2026)

Trois scripts qui n'ont pas été écrits pour tester le paquet : un script de
cours de séries temporelles de l'auteur (non publié ici), un gist public de
cointégration ([Zahedasghar](https://gist.github.com/Zahedasghar/e83f518b629eb7e5adc7806fc89b0f8e),
transcrit localement pour l'analyse, non redistribué, licence non précisée) et
un extrait d'un tutoriel `caret` sur la pauvreté des ménages
([mentalbreaks.rbind.io](https://www.r-bloggers.com/2019/10/predicting-household-poverty-in-latin-america-part-ii-evaluating-multi-class-classification-models-with-caret/amp/)).
La relecture manuelle a été notée **avant** l'exécution de l'outil.

| Script | Constats v0.1.0 | Problèmes relevés à la main | Constats v0.2.0 |
|---|---|---|---|
| cours de séries temporelles (`mce.R`) | 1 (REP-01) | 7 : ADF/KPSS sur résidus avec valeurs critiques inadaptées, conclusions discordantes non tranchées, `ca.jo()` sans `urca` et colonnes `Xt`/`Yt` probablement absentes de la table, ordre d'intégration vérifié sur une seule série, seconde étape (ECM) absente, ruptures non examinées, chemin absolu et sélection par position | 4 : REP-01, SER-01 (`adf.test`, `kpss.test`), REP-04 |
| gist de cointégration | 0 | `ur.df()` sur résidus de `lm()` (7 appels) dont 3 avec `type = "drift"` ; `ca.jo()` sans retards justifiés | 1 (SER-01 : 7 appels) |
| extrait `caret` | 0 | 2 hypothèses non tranchables sur l'extrait (fuite entre membres d'un même ménage si la cible est constante dans le ménage ; `p` sans effet avec `method = "cv"`) | 0 (SER-01 non évaluée, REP-04 évaluée sans alerte) |

**Lecture honnête.**

- La version 0.1.0 n'aurait détecté qu'un problème sur ces trois scripts, et
  le moins grave : elle n'avait aucune règle sur les séries temporelles.
- SER-01 et REP-04 ont été écrites **après** la lecture de ces scripts. Leur
  détection sur ces mêmes scripts est donc un test de non-régression, pas une
  mesure de performance. Aucune précision ni aucun rappel n'en découle.
- Quatre des sept problèmes de `mce.R` restent sans règle (conclusions
  discordantes, ordre d'intégration des deux séries, seconde étape, ruptures) :
  certains relèvent du jugement et ne se détectent pas mécaniquement.
- **Erreur de ma relecture manuelle, corrigée par l'outil.** J'avais noté
  `as.yearqtr()` sans `zoo` chargé dans le gist. REP-04 ne le signale pas, à
  raison : le gist charge `vars`, dont le champ `Depends` (CRAN, `vars` 1.6-1)
  contient `strucchange`, lui-même dépendant de `zoo`, ce qui attache `zoo`.
  Un jugement manuel n'est pas une vérité de référence.
- Le gist est un support pédagogique écrit par un enseignant, et l'extrait
  `caret` un tutoriel : leur densité d'erreurs n'est pas celle de travaux de
  recherche. Trois scripts, dont deux de séries temporelles, ne forment pas un
  corpus.

## Ce qui n'a pas été mesuré

- Taux de faux positifs et de faux négatifs sur un corpus de scripts
  indépendants et variés (autres auteurs, autres paquets, scripts très
  longs).
- Comportement sur des scripts en R Markdown / Quarto, ou répartis sur
  plusieurs fichiers (`source()`).
- Concordance des règles DEM avec la pratique des démographes.
- Les seuils conventionnels ne sont calibrés sur aucun corpus.

Si vous testez le paquet sur vos scripts, un retour structuré (script
minimal, règle, attendu, observé) est la contribution la plus utile.
