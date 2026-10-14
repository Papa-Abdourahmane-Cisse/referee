# Inférence des métadonnées depuis le script ----------------------------------
#
# Un script qui construit un plan de sondage (`svydesign()`) déclare déjà, dans
# son code, la variable de poids, les grappes, les strates et la table
# d'enquête. Cette lecture évite à l'utilisateur de les ressaisir. Elle ne
# porte que sur ce qui est écrit : tout ce qui est inféré est signalé comme tel
# dans le rapport et doit être confirmé par l'auteur du script.

SURVEY_DESIGN_FUNCTIONS <- c("svydesign", "as_survey_design", "svrepdesign",
                             "as_survey")

# Variable citée par une formule (`~poids`) ou une chaîne (`"poids"`).
formula_var <- function(e) {
  if (is.call(e) && identical(e[[1L]], as.name("~")) && length(e) == 2L) {
    e <- e[[2L]]
  }
  if (is.name(e)) {
    return(as.character(e))
  }
  if (is.character(e) && length(e) == 1L) {
    return(e)
  }
  NULL
}

# Argument nommé d'un appel, ou NULL.
named_arg <- function(cl, names_) {
  nms <- names(cl)
  if (is.null(nms)) return(NULL)
  i <- which(nms %in% names_)
  if (length(i) == 0L) NULL else cl[[i[[1L]]]]
}

#' Inférer les métadonnées d'un script
#'
#' Lit les appels de construction d'un plan de sondage (`svydesign()`,
#' `as_survey_design()`) et en tire la variable de poids (`weights`), les
#' grappes (`psu`), les strates (`strata`) et la table d'enquête
#' (`data_objects`). Les valeurs ambiguës (plusieurs plans avec des poids
#' différents) ne sont pas inférées. Un plan sans grappe (`ids = ~1`) ne
#' fournit pas de `psu`.
#'
#' L'inférence ne lit que le code : elle ne remplace pas la déclaration de
#' l'auteur et ne dit rien d'une variable de poids utilisée sans plan.
#'
#' @param script Chemin d'un script R ou objet issu de [parse_script()].
#' @return Un objet `referee_meta` portant l'attribut `inferred`, la liste des
#'   champs inférés.
#' @export
infer_meta <- function(script) {
  if (is.character(script)) script <- parse_script(path = script)
  calls <- Filter(function(r) !is.na(r$name) &&
                    r$name %in% SURVEY_DESIGN_FUNCTIONS, collect_calls(script))
  weights <- character()
  psu <- character()
  strata <- character()
  objects <- character()
  for (rec in calls) {
    cl <- rec$call
    w <- formula_var(named_arg(cl, c("weights", "weight")))
    if (!is.null(w)) weights <- c(weights, w)
    id <- formula_var(named_arg(cl, c("ids", "id")))
    if (!is.null(id) && !id %in% c("1", "0")) psu <- c(psu, id)
    st <- formula_var(named_arg(cl, "strata"))
    if (!is.null(st)) strata <- c(strata, st)
    dat <- named_arg(cl, "data")
    if (is.null(dat)) {
      nms <- names(cl)
      pos <- if (is.null(nms)) seq_along(cl)[-1L] else which(nms == "")[-1L]
      if (length(pos) >= 1L) dat <- cl[[tail(pos, 1L)]]
    }
    root <- if (is.null(dat)) NULL else data_root(dat)
    if (!is.null(root)) objects <- c(objects, root)
  }
  inferred <- list()
  pick <- function(x) {
    x <- unique(x)
    if (length(x) == 1L) x else NULL
  }
  w <- pick(weights)
  if (!is.null(w)) inferred$weights <- w
  p <- pick(psu)
  if (!is.null(p)) inferred$psu <- p
  s <- pick(strata)
  if (!is.null(s)) inferred$strata <- s
  o <- unique(objects)
  if (length(o) > 0L) inferred$data_objects <- o
  meta <- do.call(referee_meta, inferred)
  attr(meta, "inferred") <- inferred
  meta
}

# Complète `meta` avec les champs inférés ; un champ déjà déclaré par
# l'utilisateur n'est jamais remplacé. Renvoie la méta et les champs ajoutés.
merge_inferred <- function(meta, inferred_meta) {
  added <- list()
  for (field in names(attr(inferred_meta, "inferred"))) {
    if (is.null(meta[[field]])) {
      meta[[field]] <- inferred_meta[[field]]
      added[[field]] <- inferred_meta[[field]]
    }
  }
  attr(meta, "inferred") <- added
  meta
}
