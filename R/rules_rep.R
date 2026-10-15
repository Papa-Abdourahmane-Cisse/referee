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

path_argument <- function(cl, name = NA_character_) {
  nms <- names(cl)
  cand <- NULL
  if (!is.null(nms) && any(nms %in% c("file", "path", "con"))) {
    cand <- cl[[which(nms %in% c("file", "path", "con"))[1L]]]
  } else {
    pos <- if (!is.na(name) && name %in% SECOND_ARGUMENT_PATH) 3L else 2L
    if (length(cl) >= pos) cand <- cl[[pos]]
  }
  cand
}

literal_path <- function(cl, name = NA_character_) {
  cand <- path_argument(cl, name)
  if (is.character(cand) && length(cand) == 1L && !is.na(cand)) cand else NULL
}

# Chemins affectés à une variable au premier niveau du script :
# `chemin <- "C:/data/"`, `f <- file.path(chemin, "a")`, etc. Renvoie une
# liste nommée de chaînes ; une variable dont la valeur n'est pas entièrement
# lisible dans le code (appel de fonction inconnue) est ignorée.
path_assignments <- function(script) {
  env <- list()
  for (e in as.list(script$exprs)) {
    if (!is.call(e) || length(e) != 3L ||
          !as.character(e[[1L]])[1L] %in% c("<-", "=", "<<-") ||
          !is.name(e[[2L]])) next
    val <- resolve_path_expr(e[[3L]], env)
    if (!is.null(val)) env[[as.character(e[[2L]])]] <- val
  }
  env
}

# Évalue une expression de chemin sans exécuter de code : chaînes littérales,
# variables connues et concaténations par `paste0()`, `paste()`, `file.path()`.
# Renvoie `list(prefix, complete)` : le début lisible du chemin et son
# caractère complet ; NULL si même le début est inconnu.
resolve_path_expr <- function(e, env) {
  if (is.character(e) && length(e) == 1L && !is.na(e)) {
    return(list(prefix = e, complete = TRUE))
  }
  if (is.name(e)) {
    return(env[[as.character(e)]])
  }
  if (is.call(e)) {
    nm <- call_name(e)
    if (!is.na(nm) && nm %in% c("paste0", "paste", "file.path")) {
      args <- as.list(e)[-1L]
      if (!is.null(names(args))) {
        args <- args[!names(args) %in% c("sep", "collapse")]
      }
      sep <- if (nm == "paste0") "" else if (nm == "file.path") "/" else " "
      parts <- character()
      complete <- TRUE
      for (a in args) {
        r <- resolve_path_expr(a, env)
        if (is.null(r)) {
          complete <- FALSE
          break
        }
        parts <- c(parts, r$prefix)
        if (!r$complete) {
          complete <- FALSE
          break
        }
      }
      if (length(parts) == 0L) return(NULL)
      prefix <- paste(parts, collapse = sep)
      return(list(prefix = prefix, complete = complete))
    }
  }
  NULL
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
#' Les chemins construits par `paste0()`, `paste()` ou `file.path()` à partir
#' de chaînes littérales et de variables affectées au premier niveau du script
#' sont reconstitués sans exécuter le code ; pour un chemin partiellement
#' connu, seul le début est examiné (chemin absolu), pas l'existence du
#' fichier.
#'
#' Limite connue : un chemin issu d'une fonction (`here::here()`, `getwd()`,
#' une variable lue ailleurs) n'est pas évalué. Les adresses web sont ignorées.
#'
#' @param script Objet issu de [parse_script()].
#' @param project_dir Racine du projet, ou `NULL`.
#' @return Liste de constats.
#' @export
rep01_paths <- function(script, project_dir = NULL) {
  out <- list()
  env <- path_assignments(script)
  for (rec in collect_calls(script)) {
    if (is.na(rec$name) || !rec$name %in% c(READ_FUNCTIONS, WRITE_FUNCTIONS)) next
    arg <- path_argument(rec$call, rec$name)
    if (is.null(arg)) next
    r <- resolve_path_expr(arg, env)
    if (is.null(r)) next
    p <- r$prefix
    if (grepl("^[A-Za-z][A-Za-z0-9+.-]*://", p)) next
    via <- if (is.name(arg) || is.call(arg)) {
      vars <- intersect(expr_tokens(arg), names(env))
      if (length(vars) > 0L) {
        sprintf(" (obtenu via la variable `%s`)", vars[[1L]])
      } else ""
    } else ""
    if (is_absolute_path(p)) {
      out[[length(out) + 1L]] <- new_finding(
        "REP-01", "risque_probable",
        sprintf(paste0("`%s()` utilise le chemin absolu \u00ab %s \u00bb%s, propre ",
                       "\u00e0 une machine. Utiliser un chemin relatif \u00e0 la ",
                       "racine du projet."), rec$name, p, via),
        location = call_location(rec))
    } else if (r$complete && !is.null(project_dir) &&
                 rec$name %in% READ_FUNCTIONS &&
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

# Paquet(s) qui fournissent des fonctions courantes. Seules des fonctions dont
# le nom est propre à un paquet figurent ici ; plusieurs paquets sont listés
# lorsque deux paquets exportent la même fonction.
FUNCTION_PACKAGES <- list(
  ca.jo = "urca", cajorls = "urca", ca.po = "urca", ur.df = "urca",
  ur.kpss = "urca", ur.pp = "urca", ur.ers = "urca", ur.sp = "urca",
  adf.test = c("tseries", "aTSA"), kpss.test = c("tseries", "aTSA"),
  pp.test = c("tseries", "aTSA"), po.test = "tseries",
  as.yearqtr = "zoo", as.yearmon = "zoo", rollmean = "zoo",
  VAR = "vars", VARselect = "vars", vec2var = "vars",
  svydesign = "survey", svymean = "survey", svytotal = "survey",
  svyglm = "survey", svytable = "survey", svyby = "survey",
  as_survey_design = "srvyr",
  feols = "fixest", feglm = "fixest",
  coeftest = "lmtest", bptest = "lmtest", dwtest = "lmtest",
  vcovHC = "sandwich", vcovCL = "sandwich",
  ivreg = c("AER", "ivreg"), plm = "plm",
  ranger = "ranger", randomForest = "randomForest",
  glmnet = "glmnet", cv.glmnet = "glmnet",
  createDataPartition = "caret", createFolds = "caret",
  trainControl = "caret",
  read_excel = "readxl", read_xls = "readxl", read_xlsx = "readxl",
  read_dta = "haven", read_sav = "haven", read_sas = "haven",
  ggplot = "ggplot2", pivot_longer = "tidyr", pivot_wider = "tidyr"
)

# Paquets attachés en cascade (champ Depends, ou méta-paquet) par un paquet
# chargé avec `library()`. Table fixe et prudente : un paquet absent de cette
# liste est supposé ne rien attacher d'autre, ce qui peut produire un faux
# positif si ce n'est pas le cas.
ATTACH_CASCADE <- list(
  tidyverse = c("ggplot2", "dplyr", "tidyr", "readr", "purrr", "tibble",
                "stringr", "forcats", "lubridate"),
  vars = c("MASS", "strucchange", "urca", "lmtest", "sandwich", "zoo"),
  AER = c("car", "carData", "lmtest", "sandwich", "survival", "zoo"),
  survey = c("grid", "Matrix", "survival"),
  strucchange = c("zoo", "sandwich"), lmtest = "zoo", car = "carData",
  dynlm = "zoo", xts = "zoo", quantmod = c("xts", "zoo", "TTR"),
  caret = c("lattice", "ggplot2")
)

# Paquets chargés par le script, avec la ligne du premier chargement.
# Renvoie NULL si un chargement n'est pas lisible dans le code (nom de paquet
# calculé, `character.only`, boucle sur `library`).
attached_packages <- function(script) {
  calls <- collect_calls(script)
  loaders <- Filter(function(r) !is.na(r$name) &&
                      r$name %in% c("library", "require", "p_load"), calls)
  tokens <- unlist(lapply(as.list(script$exprs), expr_tokens))
  n_bare <- sum(tokens %in% c("library", "require"))
  n_calls <- sum(vapply(loaders, function(r) r$name %in% c("library", "require"),
                        logical(1)))
  if (n_bare != n_calls) return(NULL)
  att <- list()
  add <- function(pkg, line) {
    for (p in c(pkg, ATTACH_CASCADE[[pkg]])) {
      att[[p]] <<- if (is.null(att[[p]])) line else min(att[[p]], line)
    }
  }
  for (r in loaders) {
    nms <- names(r$call)
    if (!is.null(nms) && "character.only" %in% nms) return(NULL)
    args <- as.list(r$call)[-1L]
    if (!is.null(nms)) {
      args <- args[!nms[-1L] %in% c("quietly", "warn.conflicts", "install",
                                    "update", "character.only")]
    }
    if (r$name == "p_load") {
      pk <- args
    } else {
      pk <- args[seq_len(min(1L, length(args)))]
    }
    for (a in pk) {
      if (is.name(a)) add(as.character(a), r$line)
      else if (is.character(a) && length(a) == 1L) add(a, r$line)
      else return(NULL)
    }
  }
  att
}

#' REP-04 : fonction d'un paquet non chargé
#'
#' Signale l'appel de premier niveau d'une fonction connue pour appartenir à un
#' paquet (`ca.jo()` pour `urca`, `as.yearqtr()` pour `zoo`, `read_excel()` pour
#' `readxl`, `svydesign()` pour `survey`, etc.) lorsque le script ne charge
#' pas ce paquet avant l'appel, ne le préfixe pas (`urca::ca.jo()`) et ne
#' définit pas lui-même la fonction. L'exécution s'arrêterait sur « could not
#' find function ». Les paquets attachés en cascade (`library(vars)` attache
#' `urca`, par exemple) sont pris en compte par une table fixe.
#'
#' Limites connues : la liste des fonctions reconnues est courte et ne
#' couvre pas tous les paquets ; un paquet chargé hors du script (fichier
#' `.Rprofile`, script appelé par `source()`) n'est pas vu, d'où le niveau
#' « risque probable » ; la table des paquets attachés en cascade est
#' volontairement prudente mais incomplète, et un paquet absent de la table qui
#' attache lui-même d'autres paquets peut provoquer un faux positif. Si le
#' script charge des paquets de façon dynamique (`character.only = TRUE`,
#' boucle sur `library`), la règle est non évaluée.
#'
#' @param script Objet issu de [parse_script()].
#' @return Liste de constats (un par paquet manquant), ou une liste marquée
#'   « non évaluée » si les chargements de paquets ne sont pas lisibles.
#' @export
rep04_unattached_package <- function(script) {
  att <- attached_packages(script)
  if (is.null(att)) {
    return(not_evaluated(paste0("chargement dynamique de paquets (",
                                "`character.only`, boucle sur `library`) non r\u00e9solu")))
  }
  exprs <- as.list(script$exprs)
  defined <- character()
  for (e in exprs) {
    if (is.call(e) && length(e) == 3L &&
          as.character(e[[1L]])[1L] %in% c("<-", "=", "<<-") && is.name(e[[2L]])) {
      defined <- c(defined, as.character(e[[2L]]))
    }
  }
  sourced <- has_call(collect_calls(script), "source")
  missing <- list()
  for (rec in toplevel_calls(script)) {
    nm <- rec$name
    if (is.na(nm) || is.null(FUNCTION_PACKAGES[[nm]])) next
    if (is.call(rec$call[[1L]])) next # `pkg::f()` : paquet explicite
    if (nm %in% defined) next
    pk <- FUNCTION_PACKAGES[[nm]]
    ok <- any(vapply(pk, function(p) !is.null(att[[p]]) && att[[p]] <= rec$line,
                     logical(1)))
    if (ok) next
    key <- pk[1L]
    missing[[key]] <- c(missing[[key]], list(rec))
  }
  out <- list()
  for (pkg in names(missing)) {
    recs <- missing[[pkg]]
    fns <- unique(vapply(recs, function(r) r$name, character(1)))
    out[[length(out) + 1L]] <- new_finding(
      "REP-04", "risque_probable",
      sprintf(paste0("%s %s du paquet `%s` %s appel\u00e9%s sans `library(%s)` pr\u00e9alable ",
                     "ni pr\u00e9fixe `%s::` : l'ex\u00e9cution s'arr\u00eaterait sur ",
                     "\u00ab could not find function \u00bb.%s"),
              if (length(fns) > 1L) "Les fonctions" else "La fonction",
              paste0(paste0("`", fns, "()`"), collapse = ", "), pkg,
              if (length(fns) > 1L) "sont" else "est",
              if (length(fns) > 1L) "es" else "e", pkg, pkg,
              if (sourced) " Le script appelle `source()` : le paquet peut y \u00eatre charg\u00e9." else ""),
      location = call_location(recs[[1L]]),
      details = list(package = pkg, functions = fns, n_calls = length(recs)))
  }
  out
}
