# Registre des règles, exécution et rapport -----------------------------------

# Chaque entrée décrit une règle : son identifiant, sa famille, ce dont elle a
# besoin (données et/ou script), les métadonnées obligatoires, la fonction qui
# l'implémente et la manière de construire ses arguments depuis le contexte.
rule_registry <- function() {
  list(
    list(id = "SUR-01", family = "SUR", needs = "script", meta = "weights",
         fun = sur01_unweighted_estimators,
         args = function(ctx) {
           list(script = ctx$script, weights = ctx$meta$weights,
                data_objects = ctx$meta$data_objects)
         }),
    list(id = "SUR-02", family = "SUR", needs = "script",
         meta = c("weights", "size"),
         fun = sur02_weight_divided_by_size,
         args = function(ctx) {
           list(script = ctx$script, weights = ctx$meta$weights,
                size = ctx$meta$size)
         }),
    list(id = "SUR-03", family = "SUR", needs = "script", meta = character(),
         fun = sur03_design_ignored,
         args = function(ctx) {
           list(script = ctx$script, strata = ctx$meta$strata,
                psu = ctx$meta$psu)
         }),
    list(id = "SUR-04", family = "SUR", needs = "data", meta = "weights",
         fun = sur04_weights_valid,
         args = function(ctx) {
           list(data = ctx$data, weights = ctx$meta$weights)
         }),
    list(id = "LVL-01", family = "LVL", needs = "data",
         meta = c("group", "group_vars"),
         fun = lvl01_artificial_disaggregation,
         args = function(ctx) {
           list(data = ctx$data, group = ctx$meta$group,
                vars = ctx$meta$group_vars)
         }),
    list(id = "LVL-02", family = "LVL", needs = "script",
         meta = "aggregated_vars",
         fun = lvl02_unweighted_mean_of_aggregates,
         args = function(ctx) {
           list(script = ctx$script, aggregated_vars = ctx$meta$aggregated_vars)
         }),
    list(id = "LVL-03", family = "LVL", needs = "data", meta = "key",
         fun = lvl03_duplicate_keys,
         args = function(ctx) list(data = ctx$data, key = ctx$meta$key)),
    list(id = "NUM-01", family = "NUM", needs = "data", meta = "scales",
         fun = num01_bounds,
         args = function(ctx) list(data = ctx$data, scales = ctx$meta$scales)),
    list(id = "NUM-02", family = "NUM", needs = "data", meta = "sums",
         fun = num02_sums,
         args = function(ctx) list(data = ctx$data, sums = ctx$meta$sums)),
    list(id = "NUM-03", family = "NUM", needs = "data", meta = "fgt_cols",
         fun = num03_fgt_order,
         args = function(ctx) {
           list(data = ctx$data, cols = ctx$meta$fgt_cols)
         }),
    list(id = "NUM-04", family = "NUM", needs = "data", meta = character(),
         fun = num04_missing_codes,
         args = function(ctx) list(data = ctx$data))
  )
}

#' Identifiants des règles implémentées
#' @return Vecteur de caractères.
#' @export
rule_ids <- function() {
  vapply(rule_registry(), function(r) r$id, character(1))
}

#' Auditer des données et/ou un script R
#'
#' Exécute toutes les règles dont les entrées sont disponibles. Une règle
#' dont les données, le script ou les métadonnées manquent est rapportée comme
#' non évaluée : elle n'est jamais comptée comme passée sans alerte.
#'
#' @param data Data frame ou `NULL`.
#' @param script Chemin d'un script R, objet issu de [parse_script()] ou
#'   `NULL`.
#' @param meta Métadonnées, voir [referee_meta()].
#' @param params Liste nommée par identifiant de règle, qui surcharge les
#'   paramètres d'une règle, par exemple
#'   `list("SUR-04" = list(ratio_max_median = 50))`.
#' @return Un objet de classe `referee_report`.
#' @export
audit <- function(data = NULL, script = NULL, meta = referee_meta(),
                  params = list()) {
  if (!inherits(meta, "referee_meta")) {
    stop("`meta` doit \u00eatre cr\u00e9\u00e9 par `referee_meta()`.", call. = FALSE)
  }
  if (!is.null(data) && !is.data.frame(data)) {
    stop("`data` doit \u00eatre un data frame.", call. = FALSE)
  }
  if (is.character(script)) {
    script <- parse_script(path = script)
  }
  if (!is.null(script) && !inherits(script, "referee_script")) {
    stop("`script` doit \u00eatre un chemin ou un objet de `parse_script()`.",
         call. = FALSE)
  }
  if (!is.null(data)) {
    check_meta_columns(meta, data)
  }
  ctx <- list(data = data, script = script, meta = meta)

  findings <- list()
  rows <- list()
  for (spec in rule_registry()) {
    reason <- NULL
    if ("data" %in% spec$needs && is.null(data)) {
      reason <- "donn\u00e9es non fournies"
    } else if ("script" %in% spec$needs && is.null(script)) {
      reason <- "script non fourni"
    } else {
      absent <- spec$meta[vapply(spec$meta, function(f) is.null(meta[[f]]),
                                 logical(1))]
      if (length(absent) > 0L) {
        reason <- paste0("m\u00e9tadonn\u00e9es manquantes : ",
                         paste(absent, collapse = ", "))
      }
    }
    result <- list()
    if (is.null(reason)) {
      extra <- params[[spec$id]]
      if (is.null(extra)) extra <- list()
      result <- do.call(spec$fun, utils::modifyList(spec$args(ctx), extra))
      reason <- attr(result, "not_evaluated")
    }
    evaluated <- is.null(reason)
    findings <- c(findings, if (evaluated) result else list())
    rows[[length(rows) + 1L]] <- data.frame(
      rule_id = spec$id, family = spec$family,
      status = if (evaluated) "evaluee" else "non_evaluee",
      n_findings = if (evaluated) length(result) else NA_integer_,
      reason = if (evaluated) NA_character_ else reason,
      stringsAsFactors = FALSE
    )
  }
  structure(
    list(findings = findings, rules = do.call(rbind, rows)),
    class = "referee_report"
  )
}

#' @export
as.data.frame.referee_report <- function(x, ...) {
  if (length(x$findings) == 0L) {
    return(data.frame(rule_id = character(), severity = character(),
                      location = character(), message = character(),
                      stringsAsFactors = FALSE))
  }
  data.frame(
    rule_id = vapply(x$findings, function(f) f$rule_id, character(1)),
    severity = vapply(x$findings, function(f) f$severity, character(1)),
    location = vapply(x$findings, function(f) f$location, character(1)),
    message = vapply(x$findings, function(f) f$message, character(1)),
    stringsAsFactors = FALSE
  )
}

#' @export
print.referee_report <- function(x, ...) {
  rules <- x$rules
  n_eval <- sum(rules$status == "evaluee")
  cat("Rapport d'audit du R\u00e9f\u00e9r\u00e9\n")
  cat(sprintf("%d r\u00e8gle(s) \u00e9valu\u00e9e(s) sur %d ; %d non \u00e9valu\u00e9e(s).\n",
              n_eval, nrow(rules), nrow(rules) - n_eval))
  if (length(x$findings) == 0L) {
    cat("\nAucune alerte parmi les r\u00e8gles \u00e9valu\u00e9es. Cela ne vaut pas validation",
        "de l'analyse.\n")
  } else {
    for (sev in SEVERITIES) {
      sel <- Filter(function(f) f$severity == sev, x$findings)
      if (length(sel) == 0L) next
      cat(sprintf("\n== %s (%d) ==\n", SEVERITY_LABELS[[sev]], length(sel)))
      for (f in sel) print(f)
    }
    cat("\nL'absence d'alerte sur une r\u00e8gle ne vaut pas validation.\n")
  }
  skipped <- rules[rules$status == "non_evaluee", , drop = FALSE]
  if (nrow(skipped) > 0L) {
    cat("\nR\u00e8gles non \u00e9valu\u00e9es :\n")
    for (i in seq_len(nrow(skipped))) {
      cat(sprintf("  %s : %s\n", skipped$rule_id[i], skipped$reason[i]))
    }
  }
  invisible(x)
}
