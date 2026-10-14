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

## Quatre scripts d'exemple (écrits pour l'occasion)

Les scripts de `inst/examples/` ont été écrits par l'auteur des règles en
sachant ce qu'elles détectent. Ils servent de test de non-régression, pas de
validation indépendante.

| Script | Attendu | Observé |
|---|---|---|
| `enquete_propre.R` | aucune alerte | aucune alerte |
| `enquete_fautive.R` | 3 SUR-01, 1 SUR-03, 2 REP-01 ; le recensement non signalé | conforme |
| `ml_fuite.R` | VAL-01, VAL-02, VAL-03, REP-02 | conforme (VAL-04 évaluée, sans alerte) |
| `did_fautif.R` | ECO-03 | conforme ; ECO-01 évaluée sans alerte (ECO-01 n'examine pas `feols()`) ; ECO-02 non évaluée (il faut les données) |

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
