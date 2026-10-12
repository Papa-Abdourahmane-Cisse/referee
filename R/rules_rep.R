# Famille REP : reproductibilité ----------------------------------------------
#
# Ces règles vérifient ce qu'un tiers doit pouvoir rejouer : chemins qui ne
# dépendent pas d'une machine, graines aléatoires, environnement documenté.

READ_FUNCTIONS <- c("read.csv", "read.csv2", "read.table", "read.delim",
                    "readRDS", "load", "source", "readLines", "read_csv",
                    "read_csv2", "read_tsv", "read_delim", "read_dta",
                    "read_sav", "read_spss", "read_sas", "read_excel",
                    "read_xlsx", "fread", "read_parquet", "read_feather",
                    "st_read", "read_sf", "rast", "raster")
WRITE_FUNCTIONS <- c("write.csv", "write.csv2", "write.table", "saveRDS",
                     "save", "write_csv", "write_dta", "write_xlsx", "fwrite",
                     "ggsave", "writeLines", "write_parquet", "setwd")
STOCHASTIC_FUNCTIONS <- c("sample", "sample.int", "rnorm", "runif", "rbinom",
                          "rpois", "rexp", "rgamma", "rbeta", "rt", "rchisq",
                          "rmultinom", "rnbinom", "rgeom", "rlogis",
                          "rweibull", "rcauchy", "mvrnorm", "ranger",
                          "randomForest", "vfold_cv", "initial_split",
                          "group_vfold_cv", "mc_cv", "bootstraps",
                          "createFolds", "createDataPartition", "kmeans",
                          "cv.glmnet", "mice", "missForest", "boot")
SEED_FUNCTIONS <- c("set.seed", "with_seed", "local_seed", "withr::with_seed")

# Appels de premier niveau, hors définitions de fonctions (dont l'ordre
# d'exécution n'est pas celui d'écriture).
toplevel_calls <- function(script) {
  exprs <- script$exprs
  refs <- attr(exprs, "srcref")
  calls <- list()
  for (i in seq_along(exprs)) {
    e <- exprs[[i]]
    is_def <- is.call(e) && as.character(e[[1L]])[1L] %in% c("<-", "=", "<<-") &&
      length(e) == 3L && is.call(e[[3L]]) &&
      identical(e[[3L]][[1L]], as.name("function"))
    if (is_def) next
    line <- if (is.null(refs)) i else as.integer(refs[[i]][1L])
    calls <- c(calls, walk_calls(e, line))
  }
  calls
}

# Chemin littéral passé à un appel de lecture ou d'écriture : argument nommé
# `file`, `path` ou `con`, sinon argument positionnel dont le rang dépend de la
# fonction (le chemin est le deuxième argument de `write.csv(x, "f.csv")`,
# le premier de `read.csv("f.csv")`).
SECOND_ARGUMENT_PATH <- c("write.csv", "write.csv2", "write.table", "saveRDS",
                          "write_csv", "write_dta", "write_xlsx", "fwrite",
                          "write_parquet", "writeLines")

literal_path <- function(cl, name = NA_character_) {
  nms <- names(cl)
  cand <- NULL
  if (!is.null(nms) && any(nms %in% c("file", "path", "con"))) {
    cand <- cl[[which(nms %in% c("file", "path", "con"))[1L]]]
  } else {
    pos <- if (!is.na(name) && name %in% SECOND_ARGUMENT_PATH) 3L else 2L
    if (length(cl) >= pos) cand <- cl[[pos]]
  }
  if (is.character(cand) && length(cand) == 1L && !is.na(cand)) cand else NULL
}

is_absolute_path <- function(p) {
  grepl("^(/|~|[A-Za-z]:[\\\\/]|\\\\\\\\)", p)
}

#' REP-01 : chemin propre à une machine ou fichier d'entrée introuvable
#'
#' Examine les chemins écrits en toutes lettres dans les appels de lecture
#' (`read.csv()`, `read_dta()`, `readRDS()`, etc.), d'écriture
#' (`write.csv()`, `saveRDS()`, etc.) et dans `setwd()`. Un chemin absolu
#' (`/home/...`, `C:/...`, `~/...`) est un risque probable : il ne
#' fonctionnera pas sur une autre machine. Un fichier d'entrée relatif qui
#' n'existe pas dans `project_dir` est un constat de certitude. Si
#' `project_dir` n'est pas fourni, l'existence des fichiers relatifs n'est
#' pas contrôlée. L'existence d'un chemin absolu n'est pas contrôlée non
#' plus : l'audit ne s'exécute pas forcément sur la machine de l'analyse.
#'
#' Limite connue : les chemins construits (`paste0()`, `file.path()`,
#' `here::here()`) ne sont pas évalués. Les adresses web sont ignorées.
#'
#' @param script Objet issu de [parse_script()].
#' @param project_dir Racine du projet, ou `NULL`.
#' @return Liste de constats.
#' @export
rep01_paths <- function(script, project_dir = NULL) {
  out <- list()
  for (rec in collect_calls(script)) {
    if (is.na(rec$name) || !rec$name %in% c(READ_FUNCTIONS, WRITE_FUNCTIONS)) next
    p <- literal_path(rec$call, rec$name)
    if (is.null(p) || grepl("^[A-Za-z][A-Za-z0-9+.-]*://", p)) next
    if (is_absolute_path(p)) {
      out[[length(out) + 1L]] <- new_finding(
        "REP-01", "risque_probable",
        sprintf(paste0("`%s()` utilise le chemin absolu \u00ab %s \u00bb, propre \u00e0 une ",
                       "machine. Utiliser un chemin relatif \u00e0 la racine du ",
                       "projet."), rec$name, p),
        location = call_location(rec))
    } else if (!is.null(project_dir) && rec$name %in% READ_FUNCTIONS &&
                 !file.exists(file.path(project_dir, p))) {
      out[[length(out) + 1L]] <- new_finding(
        "REP-01", "certitude",
        sprintf(paste0("Fichier d'entr\u00e9e introuvable : \u00ab %s \u00bb (lu par `%s()`, ",
                       "racine du projet : %s)."), p, rec$name, project_dir),
        location = call_location(rec))
    }
  }
  out
}

#' REP-02 : procédure stochastique sans graine aléatoire
#'
#' Signale, pour chaque fonction stochastique reconnue (`sample()`,
#' `rnorm()`, `ranger()`, `vfold_cv()`, `kmeans()`, etc.), les appels de
#' premier niveau qui ne sont précédés d'aucun `set.seed()` (ni
#' `with_seed()`) dans le script, et qui ne reçoivent pas d'argument `seed`.
#' Sans graine, deux exécutions donnent des résultats différents : constat de
#' certitude. Si le script appelle `source()`, la graine peut être fixée
#' ailleurs : le constat devient un risque probable.
#'
#' Limites connues : les appels situés dans des définitions de fonctions sont
#' ignorés ; une graine unique en début de script ne garantit pas la
#' reproductibilité d'un calcul parallèle, dont les flux aléatoires se
#' règlent séparément ; la liste des fonctions n'est pas exhaustive.
#'
#' @param script Objet issu de [parse_script()].
#' @return Liste de constats (un par fonction stochastique).
#' @export
rep02_seed <- function(script) {
  calls <- toplevel_calls(script)
  seed_lines <- vapply(Filter(function(r) !is.na(r$name) &&
                                r$name %in% SEED_FUNCTIONS, calls),
                       function(r) r$line, integer(1))
  first_seed <- if (length(seed_lines) > 0L) min(seed_lines) else Inf
  sourced <- has_call(calls, "source")
  unseeded <- Filter(function(r) {
    !is.na(r$name) && r$name %in% STOCHASTIC_FUNCTIONS &&
      !("seed" %in% names(r$call)) && r$line < first_seed
  }, calls)
  out <- list()
  for (nm in unique(vapply(unseeded, function(r) r$name, character(1)))) {
    recs <- Filter(function(r) r$name == nm, unseeded)
    out[[length(out) + 1L]] <- new_finding(
      "REP-02", if (sourced) "risque_probable" else "certitude",
      sprintf(paste0("`%s()` est appel\u00e9 %d fois sans `set.seed()` pr\u00e9alable : ",
                     "le r\u00e9sultat change d'une ex\u00e9cution \u00e0 l'autre.%s"),
              nm, length(recs),
              if (sourced) " Le script appelle `source()` : la graine peut y \u00eatre fix\u00e9e." else ""),
      location = call_location(recs[[1L]]),
      details = list(n_calls = length(recs)))
  }
  out
}

#' REP-03 : environnement logiciel non documenté
#'
#' Cherche dans `project_dir` un fichier de verrouillage des versions
#' (`renv.lock`, `packrat.lock`), un `Dockerfile` ou une sortie de
#' `sessionInfo()` enregistrée (nom de fichier contenant `sessionInfo` ou
#' `session_info`). Aucun de ces éléments : constat à justifier. La présence
#' d'un fichier n'établit pas qu'il est à jour.
#'
#' @param project_dir Racine du projet.
#' @return Liste d'au plus un constat (confiance : à justifier).
#' @export
rep03_environment <- function(project_dir) {
  if (!dir.exists(project_dir)) {
    stop(sprintf("Dossier introuvable : %s", project_dir), call. = FALSE)
  }
  files <- list.files(project_dir, recursive = TRUE, all.files = TRUE)
  files <- files[!grepl("(^|/)(\\.git|renv/library)(/|$)", files)]
  base <- basename(files)
  found <- base %in% c("renv.lock", "packrat.lock", "Dockerfile") |
    grepl("session[_.-]?info", base, ignore.case = TRUE)
  if (any(found)) return(list())
  list(new_finding(
    "REP-03", "a_justifier",
    paste0("Aucun fichier d\u00e9crivant l'environnement logiciel dans le projet : ",
           "ni `renv.lock`, ni `packrat.lock`, ni `Dockerfile`, ni sortie de ",
           "`sessionInfo()` enregistr\u00e9e. Les versions des paquets ne sont pas ",
           "tra\u00e7ables."),
    location = project_dir))
}
