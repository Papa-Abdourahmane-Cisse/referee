# Famille SER : séries temporelles ----------------------------------------------
#
# Ces règles ne jugent pas la qualité d'une analyse de séries temporelles : elles
# repèrent des constructions dont la validité statistique est connue pour poser
# problème, lorsqu'elles sont lisibles dans le code.

# Tests de racine unitaire ou de stationnarité (paquets tseries, urca, aTSA).
UNIT_ROOT_TESTS <- c("adf.test", "ur.df", "adfTest", "pp.test", "PP.test",
                     "ur.pp", "ur.ers", "kpss.test", "ur.kpss")

# Fonctions qui enveloppent une série sans la modifier de façon pertinente ici.
SERIES_WRAPPERS <- c("as.numeric", "as.vector", "c", "ts", "drop", "unlist",
                     "na.omit", "as.ts", "zoo")

# Régresseurs qui ne font que retirer une tendance déterministe : la
# régression n'est alors pas une régression de niveaux entre séries.
TREND_NAMES <- c("t", "time", "trend", "tendance", "tps", "temps")

# Retire les enveloppes (`as.numeric(x)`, `summary(m)`) : renvoie l'expression
# interne.
strip_wrappers <- function(e, extra = character()) {
  repeat {
    if (is.call(e) && length(e) >= 2L) {
      nm <- call_name(e)
      if (!is.na(nm) && nm %in% c(SERIES_WRAPPERS, extra)) {
        e <- e[[2L]]
        next
      }
    }
    break
  }
  e
}

# Formule d'un appel `lm()` si c'est une régression d'une série sur au moins une
# autre série ; NULL sinon (modèle autre que `lm()`, constante seule, simple
# retrait de tendance). Les pipes sont dépliés.
lm_levels_formula <- function(e) {
  e <- strip_wrappers(e, "summary")
  if (is.call(e) && !is.na(call_name(e)) && call_name(e) %in% PIPE_OPERATORS) {
    e <- expand_pipe(e)
    if (is.null(e)) return(NULL)
  }
  if (!is.call(e) || !identical(call_name(e), "lm")) return(NULL)
  nms <- names(e)
  is_formula <- vapply(seq_along(e), function(i) {
    x <- e[[i]]
    is.call(x) && identical(x[[1L]], as.name("~")) && length(x) == 3L
  }, logical(1))
  if (!any(is_formula)) return(NULL)
  named <- if (is.null(nms)) integer() else which(nms == "formula" & is_formula)
  f <- e[[if (length(named) > 0L) named[1L] else which(is_formula)[1L]]]
  rhs <- setdiff(expr_tokens(f[[3L]]), TREND_NAMES)
  if (length(rhs) == 0L) return(NULL)
  paste(deparse(f, width.cutoff = 200L), collapse = " ")
}

# Modèle `lm()` d'où provient un objet (nom résolu par les affectations
# antérieures) : renvoie list(model, formula) ou NULL.
resolve_lm_model <- function(e, env, depth = 0L) {
  if (depth > 6L) return(NULL)
  e <- strip_wrappers(e, "summary")
  if (is.name(e)) {
    nm <- as.character(e)
    if (is.null(env[[nm]])) return(NULL)
    out <- resolve_lm_model(env[[nm]], env, depth + 1L)
    if (!is.null(out)) out$model <- nm
    return(out)
  }
  f <- lm_levels_formula(e)
  if (is.null(f)) return(NULL)
  list(model = "lm(...)", formula = f)
}

# Résidus d'un `lm()` désignés par une expression : `reg$residuals`,
# `residuals(reg)`, `resid(reg)`, `reg[["residuals"]]`, ou une variable à
# laquelle l'un d'eux a été affecté.
resolve_residual_source <- function(e, env, depth = 0L) {
  if (depth > 6L) return(NULL)
  e <- strip_wrappers(e)
  if (is.name(e)) {
    nm <- as.character(e)
    if (is.null(env[[nm]])) return(NULL)
    return(resolve_residual_source(env[[nm]], env, depth + 1L))
  }
  if (!is.call(e)) return(NULL)
  nm <- call_name(e)
  obj <- NULL
  if (!is.na(nm) && nm %in% c("$", "[[") && length(e) == 3L) {
    field <- as.character(e[[3L]])
    if (field %in% c("residuals", "resid")) obj <- e[[2L]]
  } else if (!is.na(nm) && nm %in% c("residuals", "resid") && length(e) >= 2L) {
    obj <- e[[2L]]
  }
  if (is.null(obj)) return(NULL)
  resolve_lm_model(obj, env, depth + 1L)
}

# Série testée par un test de racine unitaire : argument `x` ou `y`, sinon le
# premier argument positionnel.
tested_series <- function(cl) {
  nms <- names(cl)
  if (!is.null(nms) && any(nms %in% c("x", "y"))) {
    return(cl[[which(nms %in% c("x", "y"))[1L]]])
  }
  unnamed <- if (is.null(nms)) seq_along(cl)[-1L] else which(nms == "")[-1L]
  if (length(unnamed) == 0L) return(NULL)
  cl[[unnamed[1L]]]
}

#' SER-01 : test de racine unitaire sur des résidus de régression
#'
#' Signale un test de racine unitaire ou de stationnarité (`adf.test()`,
#' `ur.df()`, `pp.test()`, `kpss.test()`, etc.) appliqué aux résidus d'une
#' régression `lm()` entre séries, ce que fait le test de cointégration
#' d'Engle-Granger en deux étapes. Des résidus estimés ne suivent pas la
#' distribution du test appliqué à une série observée : les valeurs critiques
#' usuelles ne conviennent pas, il faut celles d'Engle-Granger (MacKinnon) ou
#' un test conçu pour les résidus de cointégration (`po.test()`, `ca.po()`).
#' Le script est lu dans l'ordre : l'objet testé est reconnu s'il provient de
#' `reg$residuals`, `residuals(reg)`, `resid(reg)` ou d'une variable affectée
#' ainsi, et si `reg` est un `lm()` dont la formule comporte au moins un
#' régresseur autre qu'une tendance. La règle est rapportée « non évaluée » si le
#' script ne contient aucun test de racine unitaire reconnu.
#'
#' Limites connues : la règle lit la syntaxe, pas l'intention. Une régression
#' de niveaux dont les résidus sont testés pour une autre raison que la
#' cointégration est signalée à tort (constat « risque probable », à écarter
#' après lecture) ; les valeurs critiques corrigées appliquées à la main ne
#' sont pas reconnues ; les modèles autres que `lm()` (`dynlm()`, `plm()`) et
#' les résidus obtenus par `do.call()` ou une fonction personnalisée
#' échappent à la règle. Elle ne vérifie ni l'ordre d'intégration des séries
#' ni le choix des retards.
#'
#' @param script Objet issu de [parse_script()].
#' @return Liste de constats (un par fonction de test), ou une liste marquée
#'   « non évaluée » si le script ne contient aucun test de racine unitaire.
#' @export
ser01_residual_unit_root <- function(script) {
  exprs <- script$exprs
  refs <- attr(exprs, "srcref")
  env <- list()
  hits <- list()
  n_tests <- 0L
  for (i in seq_along(exprs)) {
    e <- exprs[[i]]
    line <- if (is.null(refs)) i else as.integer(refs[[i]][1L])
    is_assign <- is.call(e) && length(e) == 3L &&
      as.character(e[[1L]])[1L] %in% c("<-", "=", "<<-") && is.name(e[[2L]])
    is_def <- is_assign && is.call(e[[3L]]) &&
      identical(e[[3L]][[1L]], as.name("function"))
    if (!is_def) {
      for (rec in walk_calls(e, line)) {
        if (is.na(rec$name) || !rec$name %in% UNIT_ROOT_TESTS) next
        n_tests <- n_tests + 1L
        series <- tested_series(rec$call)
        if (is.null(series)) next
        src <- resolve_residual_source(series, env)
        if (is.null(src)) next
        type <- NULL
        if (!is.null(names(rec$call)) && "type" %in% names(rec$call) &&
              is.character(rec$call[["type"]])) {
          type <- rec$call[["type"]]
        }
        hits[[length(hits) + 1L]] <- list(rec = rec, src = src, type = type)
      }
    }
    if (is_assign) {
      env[[as.character(e[[2L]])]] <- if (is_def) NULL else e[[3L]]
    }
  }
  if (n_tests == 0L) {
    return(not_evaluated("aucun test de racine unitaire reconnu dans le script"))
  }
  out <- list()
  for (nm in unique(vapply(hits, function(h) h$rec$name, character(1)))) {
    recs <- Filter(function(h) h$rec$name == nm, hits)
    models <- unique(vapply(recs, function(h) h$src$model, character(1)))
    first <- recs[[1L]]
    types <- unique(unlist(lapply(recs, function(h) h$type)))
    types <- setdiff(types, "none")
    det_note <- if (length(types) > 0L) {
      sprintf(paste0(" Le test inclut des termes d\u00e9terministes (`type = \"%s\"`) : ",
                     "\u00e0 justifier au regard de la sp\u00e9cification de la r\u00e9gression de niveaux."),
              paste(types, collapse = "\", \""))
    } else ""
    kpss_note <- if (nm %in% c("kpss.test", "ur.kpss")) {
      paste0(" Pour le KPSS, la stationnarit\u00e9 des r\u00e9sidus de coint\u00e9gration ",
             "se teste avec des valeurs critiques propres (test de Shin), non celles du KPSS usuel.")
    } else ""
    out[[length(out) + 1L]] <- new_finding(
      "SER-01", "risque_probable",
      sprintf(paste0("`%s()` est appliqu\u00e9 %d fois aux r\u00e9sidus d'une r\u00e9gression `lm()` ",
                     "(%d mod\u00e8le(s), par exemple `%s`, formule `%s`). S'il s'agit d'un test de ",
                     "coint\u00e9gration (Engle-Granger), les valeurs critiques usuelles ne ",
                     "conviennent pas \u00e0 des r\u00e9sidus estim\u00e9s : utiliser celles d'Engle-Granger ",
                     "(MacKinnon) ou un test d\u00e9di\u00e9 (`po.test()`, `ca.po()`). Si la ",
                     "r\u00e9gression n'a pas pour objet la coint\u00e9gration, ignorer ce constat.%s%s"),
              nm, length(recs), length(models), first$src$model,
              first$src$formula, kpss_note, det_note),
      location = call_location(first$rec),
      details = list(n_calls = length(recs), models = models, types = types))
  }
  out
}
