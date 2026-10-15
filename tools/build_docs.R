# Génère docs/regles/*.md à partir du code, du catalogue et de tools/conduite.R.
# Usage (depuis la racine du dépôt) : Rscript tools/build_docs.R
suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("tools/conduite.R", encoding = "UTF-8")
cat_ <- yaml::read_yaml("inst/catalogue/rules.yml")
cat_ <- setNames(cat_, vapply(cat_, `[[`, "", "id"))
registry <- setNames(rule_registry(), vapply(rule_registry(), `[[`, "", "id"))

# --- descriptions issues des blocs roxygen -----------------------------------
roxy <- list()
for (f in list.files("R", "^rules_.*\\.R$", full.names = TRUE)) {
  s <- readLines(f, encoding = "UTF-8")
  i <- 1L
  while (i <= length(s)) {
    m <- regmatches(s[i], regexec("^#' ([A-Z]{3}-[0-9]{2}) : (.*)$", s[i]))[[1]]
    if (length(m) == 3L) {
      j <- i + 1L
      desc <- character()
      while (j <= length(s) && grepl("^#'", s[j]) && !grepl("^#' @", s[j])) {
        desc <- c(desc, sub("^#' ?", "", s[j]))
        j <- j + 1L
      }
      roxy[[m[2]]] <- desc
      i <- j
    } else i <- i + 1L
  }
}
split_desc <- function(lines) {
  txt <- paste(lines, collapse = "\n")
  paras <- trimws(strsplit(txt, "\n\\s*\n")[[1]])
  paras <- paras[nzchar(paras)]
  paras <- gsub("\n", " ", paras)
  lim <- grepl("^Limites? connues?|^Limites? :|^Ce que la règle ne dit pas", paras)
  list(corps = paras[!lim], limites = paras[lim])
}

fam_names <- c(SUR = "Plan de sondage et pondération", LVL = "Niveaux d'analyse",
               NUM = "Cohérence numérique",
               VAL = "Validation en apprentissage automatique",
               ECO = "Économétrie et identification",
               SER = "Séries temporelles", EXT = "Cohérence externe",
               REP = "Reproductibilité", DOC = "Cohérence documentaire",
               DEM = "Démographie (règles candidates)")
needs_txt <- c(data = "des données (data frame)", script = "un script R",
               document = "un document texte", project_dir = "un dossier de projet")
meta_example <- c(
  weights = "weights = \"poids\"", size = "size = \"taille_men\"",
  strata = "strata = \"strate\"", psu = "psu = \"grappe\"",
  group = "group = \"region\"", group_vars = "group_vars = \"taux\"",
  key = "key = \"id\"", aggregated_vars = "aggregated_vars = \"taux_commune\"",
  data_objects = "data_objects = \"enq\"",
  scales = "scales = c(taux = \"proportion\")",
  fgt_cols = "fgt_cols = c(\"fgt0\", \"fgt1\", \"fgt2\")",
  sums = "sums = list(list(parts = c(\"a\", \"b\"), target = 100))",
  time = "time = \"annee\"", target = "target = \"y\"",
  train_objects = "train_objects = \"train\"", test_objects = "test_objects = \"test\"",
  cluster = "cluster = \"village\"", unit = "unit = \"village\"", treat = "treat = \"traite\"",
  endog = "endog = \"x_endogene\"", instruments = "instruments = \"z\"",
  score = "score = \"score\"", cutoff = "cutoff = 50",
  references = "references = list(list(name = \"taux\", reference = 0.42, tol = 0.02, var = \"emploi\"))",
  poverty = "poverty = list(line_year = 2018, welfare_year = 2021, price_adjusted = FALSE)",
  figures = "figures = list(list(name = \"taux\", value = 37.5, pattern = \"taux de pauvreté\"))",
  indicators = "indicators = list(list(name = \"pauvreté\", pattern = \"pauvret\"))",
  design = "design = \"double différence\"", age = "age = \"age\"",
  balance = "balance = list(p0 = \"pop0\", p1 = \"pop1\", births = \"nais\", deaths = \"deces\")",
  lifetable = "lifetable = list(age = \"age\", qx = \"qx\")",
  sexratio = "sexratio = list(group = \"groupe_age\", males = \"hommes\", females = \"femmes\")")
conf_lab <- c(certitude = "certitude", risque_probable = "risque probable",
              a_justifier = "à justifier")

dir.create("docs/regles", recursive = TRUE, showWarnings = FALSE)
dir.create("inst/regles", recursive = TRUE, showWarnings = FALSE)
ids <- names(registry)
ids <- ids[order(match(substr(ids, 1, 3), names(fam_names)), ids)]
# VAL-06 suit VAL-05 dans l'ordre numérique
ids <- ids[order(match(substr(ids, 1, 3), names(fam_names)), as.integer(substr(ids, 5, 6)))]

for (id in ids) {
  sp <- registry[[id]]
  ct <- cat_[[id]]
  cd <- conduite[[id]]
  if (is.null(cd)) stop("conduite manquante : ", id)
  d <- split_desc(roxy[[id]])
  inputs <- needs_txt[sp$needs]
  meta_req <- sp$meta
  if (length(sp$needs) == 0L) inputs <- c("des métadonnées seules")
  args <- character()
  if ("data" %in% sp$needs) args <- c(args, "data = mes_donnees")
  if ("script" %in% sp$needs) args <- c(args, "script = \"analyse.R\"")
  if ("document" %in% sp$needs) args <- c(args, "document = \"rapport.md\"")
  if ("project_dir" %in% sp$needs) args <- c(args, "project_dir = \".\"")
  if (length(meta_req) > 0L) {
    mm <- unname(meta_example[meta_req])
    args <- c(args, paste0("meta = referee_meta(", paste(mm, collapse = ", "), ")"))
  }
  code <- paste0("library(referee)\nrapport <- audit(", paste(args, collapse = ",\n                  "), ")\nrapport")
  # vérification : le code d'exemple de métadonnées doit être accepté
  if (length(meta_req) > 0L) eval(parse(text = paste0("referee_meta(", paste(mm, collapse = ", "), ")")))
  out <- c(
    sprintf("# %s : %s", id, ct$titre), "",
    sprintf("**Famille** : %s (%s)  ", substr(id, 1, 3), fam_names[[substr(id, 1, 3)]]),
    sprintf("**Niveaux de confiance** : %s  ", paste(conf_lab[unlist(ct$confiance)], collapse = ", ")),
    sprintf("**Détection** : %s  ", paste(unlist(ct$detection), collapse = ", ")),
    sprintf("**Entrées requises** : %s%s", paste(inputs, collapse = " ; "),
            if (length(meta_req) > 0L) sprintf(" ; métadonnées : %s", paste0("`", meta_req, "`", collapse = ", ")) else ""),
    "",
    if (substr(id, 1, 3) == "DEM") c("> Règle candidate, non relue par un démographe : à utiliser avec prudence.", "") else NULL,
    "## Ce que la règle détecte", "", d$corps, "",
    "## Pourquoi c'est un problème", "", cd$pourquoi, "",
    "## Que faire en cas d'alerte", "", cd$conduite, "",
    "## Exemple", "", "```r", cd$exemple, "```", "",
    "## Utilisation", "", "```r", code, "```", "",
    "Si une entrée requise manque, la règle est rapportée « non évaluée » : ce n'est pas un succès.",
    ""
  )
  if (length(d$limites) > 0L) {
    out <- append(out, c("## Limites connues", "", d$limites, ""),
                  after = length(out) - 2L)
  }
  writeLines(unlist(out), file.path("docs/regles", paste0(id, ".md")), useBytes = TRUE)
}

idx <- c("# Catalogue des règles", "",
         "Chaque fiche décrit ce que la règle détecte, pourquoi, que faire en cas d'alerte, ses limites et un exemple d'utilisation.", "",
         "| Règle | Titre | Entrées | Confiance |", "|---|---|---|---|")
for (id in ids) {
  sp <- registry[[id]]
  inp <- paste(c(sp$needs, if (length(sp$meta)) "méta"), collapse = " + ")
  if (!nzchar(inp)) inp <- "méta"
  idx <- c(idx, sprintf("| [%s](%s.md) | %s | %s | %s |", id, id, cat_[[id]]$titre, inp,
                        paste(conf_lab[unlist(cat_[[id]]$confiance)], collapse = ", ")))
}
writeLines(idx, "docs/regles/README.md", useBytes = TRUE)
cat(length(ids), "fiches générées\n")

file.copy(list.files("docs/regles", full.names = TRUE), "inst/regles", overwrite = TRUE)
