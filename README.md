# referee : détecteur d'erreurs méthodologiques pour statisticiens et économistes

[![R-CMD-check](https://github.com/Papa-Abdourahmane-Cisse/referee/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/Papa-Abdourahmane-Cisse/referee/actions/workflows/R-CMD-check.yaml)

`referee` relit un script R, des données, un document ou un dossier de projet
à la manière d'un relecteur méthodologique : il applique **36 règles
déterministes** (pas d'apprentissage automatique, pas de score opaque) et
produit un rapport de constats, chacun classé par niveau de confiance.

> **L'absence d'alerte ne vaut pas validation.** Une règle dont les entrées
> manquent est rapportée « non évaluée », jamais comme « réussie ». Le paquet
> signale des motifs suspects et des incohérences vérifiables ; il ne
> certifie pas qu'une analyse est correcte.

Version de travail (`0.2.0`, préliminaire). Voir [Statut et limites](#statut-et-limites).

## Ce que le paquet fait, et ne fait pas

| Il peut | Il ne peut pas |
|---|---|
| Repérer dans le code des motifs à risque : estimateur non pondéré sur une enquête, plan de sondage sans grappe, fuite d'information, chemin absolu, absence de graine, etc. | Exécuter votre script ni suivre le flux réel des données : il lit le code, pas son exécution. |
| Vérifier sur les données des faits : poids invalides, doublons, proportions hors bornes, parts qui ne somment pas, violations FGT, instrument faible, etc. | Savoir ce que représente une variable : il lit les rôles que vous déclarez (ou que `svydesign()` déclare). |
| Comparer chiffres du texte et sorties, ou une estimation et une valeur officielle déclarée. | Dire si votre méthode est la bonne : une règle alerte ou se tait, elle ne tranche pas. |

## Installation

```r
install.packages("remotes")
remotes::install_github("Papa-Abdourahmane-Cisse/referee")
```

Aucun compilateur n'est nécessaire (paquet R pur). R ≥ 4.1.

## Démarrer en trois minutes

Le paquet fournit des scripts d'exemple, dont un contenant des erreurs :

```r
library(referee)

exemple <- system.file("examples", "enquete_fautive.R", package = "referee")
rapport <- audit_script(exemple)
rapport
```

Le rapport indique le nombre de règles évaluées, les métadonnées lues dans le
script, puis les constats classés par niveau de confiance, avec la ligne de
code concernée. Pour vos propres scripts :

```r
rapport <- audit_script("C:/chemin/vers/mon_script.R")   # barres obliques, même sous Windows
as.data.frame(rapport)                                   # tableau des constats
rapport$rules                                            # état de chacune des 36 règles
explain_rule("SUR-01")                                   # fiche d'une règle
```

## Lire un rapport

Chaque constat porte un niveau de confiance :

| Niveau | Sens |
|---|---|
| `certitude` | Un fait vérifiable est établi (par exemple une proportion de 1,3, un poids négatif, un `set.seed()` absent). La gravité reste à apprécier. |
| `risque_probable` | Le motif est typique d'une erreur, mais seule la documentation ou l'auteur peut trancher. |
| `a_justifier` | Pas forcément une erreur : un choix qu'un relecteur demanderait de justifier. |

Une règle est « évaluée » ou « non évaluée » (avec la raison). **Seules les
règles évaluées ont examiné votre travail.** Sur un script seul, 2 à 5 règles
sont évaluées (selon les appels qu'il contient) ; les autres attendent des données, des métadonnées, un document
ou un dossier.

## Quatre niveaux d'audit

| Vous fournissez | Règles évaluables | Exemple |
|---|---|---|
| un script | SUR-01 à 03, REP-01, REP-02, REP-04, SER-01, VAL, ECO-01, ECO-03, selon les métadonnées | `audit_script("analyse.R")` |
| + des métadonnées | davantage de règles du script (VAL, ECO, LVL-02, SUR-02) | `audit(script =, meta = referee_meta(...))` |
| + des données | contrôles numériques (SUR-04, LVL, NUM, VAL-05, ECO-02/04/05, DEM) | `audit(data =, script =, meta =)` |
| + un document, un dossier | DOC (texte et sorties), REP-03 (environnement) | `audit(document =, project_dir =)` |

Exemple complet :

```r
meta <- referee_meta(
  weights = "poids", strata = "strate", psu = "grappe",
  group = "region", key = "id_menage",
  scales = c(taux_pauvrete = "proportion")
)
rapport <- audit(data = mes_donnees, script = "analyse.R",
                 document = "rapport.md", project_dir = ".",
                 meta = meta, infer = TRUE)
```

`infer = TRUE` complète vos métadonnées avec ce que `svydesign()` déclare déjà
dans le script (poids, grappes, strates, table d'enquête). Vos déclarations
l'emportent toujours, et le rapport rappelle ce qui a été inféré.

Les seuils conventionnels (dispersion des poids, codes de valeurs manquantes,
plage de masculinité, etc.) se règlent règle par règle :

```r
audit(data = d, meta = meta, params = list("SUR-04" = list(ratio_max_median = 50)))
```

## Les 36 règles

Chaque règle a [une fiche](docs/regles/README.md) : ce qu'elle détecte,
pourquoi, que faire en cas d'alerte, ses limites, un exemple.

| Famille | Règles | Objet |
|---|---|---|
| SUR | 01 à 04 | Plan de sondage et pondération |
| LVL | 01 à 03 | Niveaux d'analyse (désagrégation artificielle, moyennes d'agrégats, doublons) |
| NUM | 01 à 04 | Cohérence numérique (bornes, sommes, ordre FGT, codes de non-réponse) |
| VAL | 01 à 06 | Validation en apprentissage automatique (fuite d'information, découpages) |
| ECO | 01 à 05 | Économétrie : grappes, double différence, instruments faibles, discontinuité |
| SER | 01 | Séries temporelles : test de racine unitaire sur des résidus de régression |
| EXT | 01, 02 | Cohérence externe (valeur de référence, ligne de pauvreté) |
| REP | 01 à 04 | Reproductibilité (chemins, graine, environnement, paquets non chargés) |
| DOC | 01 à 03 | Cohérence entre texte et sorties, langage causal |
| DEM | 01 à 04 | Démographie : **règles candidates, non relues par un démographe** |

Le catalogue neutre (indépendant du langage) est dans
[`inst/catalogue/rules.yml`](inst/catalogue/rules.yml).

## Guide pas à pas

Le [guide de l'utilisateur](docs/guide-utilisateur.md) part de zéro : installer
R, installer le paquet, auditer un premier script, comprendre le rapport,
passer aux données.

## Statut et limites

- **Version de travail.** L'interface peut encore changer.
- **Validation partielle.** Le paquet est testé sur données simulées (chaque
  règle a un test positif et une « jumelle négative » correcte). Sa précision
  a été mesurée sur un seul script réel et quatre scripts écrits pour
  l'occasion, ce qui ne permet pas d'estimer des taux de faux positifs ou de
  faux négatifs généraux. Voir [docs/validation.md](docs/validation.md).
- **Analyse statique.** Un appel construit dynamiquement (`do.call`, `eval`),
  un objet intermédiaire renommé ou une fonction non répertoriée échappent aux
  règles de script. Chaque fiche liste ses limites propres.
- **Seuils.** Plusieurs seuils sont des conventions de pratique, pas des
  résultats établis ; ils sont paramétrables.
- **Démographie.** Les règles DEM sont des propositions à faire relire.
- **Références.** [docs/references.md](docs/references.md) distingue les
  références vérifiées de celles qui restent à vérifier.

## Contribuer

Voir [CONTRIBUTING.md](CONTRIBUTING.md). Signaler un faux positif ou un faux
négatif avec un extrait de script minimal est la contribution la plus utile.

## Citation et licence

GPL-3 (voir `COPYING`). Auteur : Papa Abdourahmane Cissé. Pour citer le
paquet : `citation("referee")`.
