# Guide de l'utilisateur

Ce guide s'adresse à quelqu'un qui découvre le dépôt. Il ne suppose aucune
connaissance préalable du paquet.

## 1. Ce dont vous avez besoin

- **R** (version 4.1 ou plus récente) : <https://cran.r-project.org>.
- Facultatif : RStudio ou Positron comme éditeur.
- Aucune autre installation : le paquet est écrit en R pur.

## 2. Installer le paquet

Dans la console R :

```r
install.packages("remotes")                       # une seule fois
remotes::install_github("Papa-Abdourahmane-Cisse/referee")
library(referee)
length(rule_ids())                                # doit afficher 36
```

Si R signale qu'un paquet est « en cours d'utilisation », redémarrez R
(Session > Restart R) puis relancez l'installation.

## 3. Premier audit : un script d'exemple

```r
exemple <- system.file("examples", "enquete_fautive.R", package = "referee")
rapport <- audit_script(exemple)
rapport
```

Quatre scripts d'exemple sont fournis dans `system.file("examples", package = "referee")` :

| Script | Contenu |
|---|---|
| `enquete_propre.R` | analyse d'enquête sans erreur détectable (aucune alerte attendue) |
| `enquete_fautive.R` | moyennes non pondérées, plan sans grappe, chemin absolu |
| `ml_fuite.R` | standardisation avant découpage, découpage aléatoire, performance d'apprentissage |
| `did_fautif.R` | double différence sans examen des tendances pré-traitement |

## 4. Lire le rapport

Le rapport comporte, dans l'ordre :

1. **Le décompte** : « 5 règle(s) évaluée(s) sur 36 ». Les 31 autres n'ont rien
   examiné, faute d'entrées.
2. **Les métadonnées inférées** du script (poids, grappes, strates, table
   d'enquête), à confirmer.
3. **Les constats**, classés `certitude`, `risque probable`, `à justifier`,
   chacun avec la règle, la ligne de code et une explication.
4. **Les règles non évaluées**, avec la raison.

Pour comprendre une règle, lisez sa fiche :

```r
explain_rule("SUR-01")
```

ou ouvrez [docs/regles/](regles/README.md) sur GitHub.

**Conduite à tenir devant une alerte.** Une alerte n'est pas un verdict. Pour
chaque constat : (1) lisez la ligne de code concernée, (2) lisez la fiche de
la règle, (3) décidez s'il s'agit d'une erreur, d'un choix à justifier dans le
texte, ou d'un faux positif (par exemple un recensement traité comme une
enquête). Un faux positif récurrent se corrige en déclarant les métadonnées
(`data_objects`) ; si c'est un défaut de l'outil, signalez-le (voir
CONTRIBUTING).

## 5. Auditer votre propre script

```r
rapport <- audit_script("C:/Users/moi/projet/analyse.R")
```

Sous Windows, utilisez des barres obliques `/` ou la notation `r"(C:\Users\moi\a.R)"`.
La barre oblique inverse `\` provoque une erreur (`\U`).

Pour obtenir les constats sous forme de tableau, puis les enregistrer :

```r
tab <- as.data.frame(rapport)
write.csv(tab, "constats_referee.csv", row.names = FALSE)
```

## 6. Enrichir l'audit avec des métadonnées

Un script seul permet d'évaluer peu de règles. Pour en évaluer davantage,
déclarez le rôle de vos variables :

```r
meta <- referee_meta(
  weights = "poids_men", strata = "strate", psu = "grappe",
  data_objects = "enes_clean"       # tables qui contiennent l'enquête
)
rapport <- audit(script = "analyse.R", meta = meta)
```

La liste complète des champs est dans `?referee_meta`. Chaque fiche de règle
indique les métadonnées qu'elle exige.

## 7. Ajouter les données, le texte, le dossier

```r
donnees <- haven::read_dta("data/enquete.dta")    # ou read.csv, readRDS...
rapport <- audit(
  data = donnees, script = "analyse.R", meta = meta,
  document = "rapport.md",     # texte, pour les règles DOC
  project_dir = ".",           # racine du projet, pour REP-01 et REP-03
  infer = TRUE
)
```

Avec les données, les règles de contrôle numérique (poids invalides, doublons,
proportions hors bornes, parts qui ne somment pas, indices FGT, etc.)
deviennent évaluables. Les variables déclarées dans `meta` doivent exister dans
`donnees`, sinon l'audit s'arrête avec un message explicite.

## 8. Ce qu'il faut retenir

- Une règle évaluée sans alerte ne prouve pas que l'analyse est correcte : elle
  prouve que ce motif précis n'a pas été trouvé.
- Une règle non évaluée n'a rien examiné.
- Les alertes sont des pistes pour un relecteur humain.
- Les règles de démographie (DEM) sont des propositions non relues par un
  démographe.

## 9. Que faire si ça ne marche pas

| Symptôme | Cause probable |
|---|---|
| `Fichier introuvable` | chemin faux ; vérifier avec `file.exists("...")` |
| `\U used without hex digits` | barres obliques inverses dans un chemin Windows |
| `Variables déclarées dans les métadonnées mais absentes des données` | faute de frappe dans `referee_meta()` ou mauvaise table |
| Installation impossible : paquet « en cours d'utilisation » | redémarrer R, puis réinstaller |
| Un résultat vous semble faux | ouvrir une *issue* GitHub avec un extrait de script minimal |
